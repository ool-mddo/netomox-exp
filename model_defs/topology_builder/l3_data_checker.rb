# frozen_string_literal: true

require_relative 'l3_segment_ledger'
require_relative 'pseudo_dsl/pseudo_model'

module TopologyBuilder
  # Explore L2 segment and construct segment-connected node information
  class L3DataChecker < PseudoDSL::DataBuilderBase
    # @!attribute [r] segments
    #   @return [L3SegmentLedger]
    attr_reader :segments

    # @param [PNetwork] layer2p Layer2 network topology
    def initialize(layer2p:, debug: false)
      super(debug:)
      @segments = L3SegmentLedger.new
      @layer2p = layer2p
    end

    protected

    # rubocop:disable Metrics/MethodLength

    # Explore layer2-connected nodes as "segment" for each node.
    # @return [void]
    def explore_l3_segment
      @layer2p.nodes.each do |src_node|
        @segments.append_new_segment
        src_node.tps.each do |src_tp|
          src_edge, dst_edge = link_edges_by_src(src_node, src_tp)
          next unless dst_edge

          @segments.current_segment.push(src_edge)
          recursively_explore_l3_segment(dst_edge)
        end
      end
      @segments.clean!
      @segments.dump if @use_debug
    end
    # rubocop:enable Metrics/MethodLength

    private

    # @param [PLinkEdge] src_edge A link-edge (source)
    # @return [PLinkEdge] Destination link-edge layer2 connected with src_edge
    def dst_edge_connected_with(src_edge)
      return if @segments.exist_segment_includes?(src_edge)

      link = @layer2p.find_link_by_src_edge(src_edge)
      return unless link

      link.dst
    end

    # rubocop:disable Metrics/AbcSize

    # Recursive exploration: layer2-connected objects
    # @param [PLinkEdge] src_edge A link-edge to specify start point
    # @return [void]
    def recursively_explore_l3_segment(src_edge)
      @segments.current_segment.push(src_edge)
      src_node = @layer2p.find_node_by_name(src_edge.node)

      src_node.tps_without(src_edge.tp).each do |src_tp|
        src_edge = PseudoDSL::PLinkEdge.new(src_node.name, src_tp.name)
        link = @layer2p.find_link_by_src_edge(src_edge)
        next if !link || @segments.current_segment.include?(link.dst) # loop avoidance

        @segments.current_segment.push(src_edge)
        recursively_explore_l3_segment(link.dst)
      end
    end
    # rubocop:enable Metrics/AbcSize

    # Convert a link edge (source) to source-destination link-edge pair
    # @param [PNode] src_node Source node
    # @param [PTermPoint] src_tp Source tp
    # @return [Array(PLinkEdge, PLinkEdge)] Source/destination link-edge pair (layer2 link edge pair)
    def link_edges_by_src(src_node, src_tp)
      src_edge = PseudoDSL::PLinkEdge.new(src_node.name, src_tp.name)
      dst_edge = dst_edge_connected_with(src_edge)
      [src_edge, dst_edge]
    end
  end
end
