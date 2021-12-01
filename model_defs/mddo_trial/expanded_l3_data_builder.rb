# frozen_string_literal: true

require_relative '../bf_common/pseudo_model'

# Expanded L3 data builder
class ExpandedL3DataBuilder < DataBuilderBase
  # @param [PNetwork] layer3p Layer3 network topology
  def initialize(layer3p:, debug: false)
    super(debug: debug)
    @layer3p = layer3p
  end

  # @return [PNetworks] Networks contains only layer3 network topology
  def make_networks
    @network = @networks.network('layer3exp')
    @network.type = Netomox::NWTYPE_L3
    expand_segment_to_p2p
    @networks
  end

  private

  # @return [Array<PNode>] Layer3 segment nodes
  def find_all_segment_nodes
    @layer3p.nodes.find_all { |node| node.attribute[:flags].include?('segment') }
  end

  # @param [PNode] orig_l3_node Layer3 node (copy source)
  # @return [PNode] expanded-layer3 node
  def add_node(orig_l3_node)
    # copy except tps
    new_src_node = @network.node(orig_l3_node.name)
    new_src_node.supports = orig_l3_node.supports
    new_src_node.attribute = orig_l3_node.attribute
    new_src_node
  end

  # @param [Integer] index Index number of new term-point
  # @param [PNode] node Node to add new term-point
  # @param [PTermPoint] orig_l3_tp Layer3 term-point (copy source)
  # @return [PTermPoint] expanded-layer3 term-point
  def add_tp(index, node, orig_l3_tp)
    # copy with indexed-name
    new_tp = node.term_point(orig_l3_tp.name + "##{index}")
    new_tp.supports = orig_l3_tp.supports
    new_tp.attribute = orig_l3_tp.attribute
    new_tp
  end

  # rubocop:disable Metrics/ParameterLists

  # @param [Integer] src_edge_index Index number of source edge
  # @param [Integer] dst_edge_index Index number of destination edge
  # @param [PNode] src_node Source layer3 node (copy source)
  # @param [PTermPoint] src_tp Source layer3 term-point (copy source)
  # @param [PNode] dst_node Destination layer3 node (copy source)
  # @param [PTermPoint] dst_tp Destination layer3 term-point (copy-source)
  # @return [Array<String>] Source/destination node/tp names (to create link)
  def add_node_tp(src_edge_index, dst_edge_index, src_node, src_tp, dst_node, dst_tp)
    new_src_node = add_node(src_node) # redundant
    new_src_tp = add_tp(dst_edge_index, new_src_node, src_tp)
    new_dst_node = add_node(dst_node)
    new_dst_tp = add_tp(src_edge_index, new_dst_node, dst_tp)
    [new_src_node, new_src_tp, new_dst_node, new_dst_tp].map(&:name)
  end
  # rubocop:enable Metrics/ParameterLists

  # @param [Array<PLinkEdge>] seg_connected_edges Edges connected a segment node
  # @return [void]
  def add_node_tp_links(seg_connected_edges)
    seg_connected_edges.each_with_index do |src_edge, si|
      src_node, src_tp = @layer3p.find_node_tp_by_edge(src_edge)
      seg_connected_edges.each_with_index do |dst_edge, di|
        next if dst_edge == src_edge

        dst_node, dst_tp = @layer3p.find_node_tp_by_edge(dst_edge)
        @network.link(*add_node_tp(si, di, src_node, src_tp, dst_node, dst_tp))
      end
    end
  end

  # Expand links connected a layer3 segment to P2P links
  # @return [void]
  def expand_segment_to_p2p
    segment_nodes = find_all_segment_nodes
    debug_print "seg nodes = #{segment_nodes.map(&:name)}"
    segment_nodes.each do |seg_node|
      seg_connected_edges = @layer3p.find_all_edges_by_src_name(seg_node.name)
      debug_print "seg edges = #{seg_connected_edges.map(&:to_s)}"
      add_node_tp_links(seg_connected_edges)
    end
  end
end
