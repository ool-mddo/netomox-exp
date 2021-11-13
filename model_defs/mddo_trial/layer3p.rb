# frozen_string_literal: true

require 'forwardable'
require_relative '../bf_common/pseudo_model'
require_relative 'csv/ip_owners_table'

# L3 segment data holder
class L3SegmentLedger
  extend Forwardable
  def_delegators :@segments, :push, :each, :each_with_index, :to_s

  def initialize
    @segments = [] # Array(Array(PLinkEdge))
  end

  # @param [PLinkEdge] edge Link-edge
  # @return [Boolean] true if there is a segment includes the link-edge
  def exist_segment_includes?(edge)
    @segments.each do |seg|
      return true if seg.include?(edge)
    end
    false
  end

  # @return [Array<PLinkEdge>] Appended link-edge array
  def append_new_segment
    seg = [] # Array<PlinkEdge>
    @segments.push(seg)
    seg
  end

  # Remove empty segment (empty array) from segments
  def clean!
    @segments.reject!(&:empty?)
  end

  # @return [Array<PLinkEdge>] current segment to push link-edge
  def current_segment
    @segments[-1]
  end

  # @return [Boolean] true if current-segment includes the link-edge
  def current_segment_include?(edge)
    current_segment.include?(edge)
  end
end

# L2 data builder
class L3DataBuilder < DataBuilderBase
  # @param [String] target Target network (config) data name
  # @param [PNetwork] layer2p Layer2 network topology
  def initialize(target, layer2p)
    super()
    @layer2p = layer2p
    @ip_owners = IPOwnersTable.new(target)
  end

  # @return [PNetworks] Networks contains only layer3 network topology
  def make_networks
    @network = PNetwork.new('layer3')
    @network.type = Netomox::NWTYPE_L3
    explore_l3_segment
    add_l3_node_tp_link

    @networks.push(@network)
    @networks
  end

  private

  # @param [IPOwnersTableRecord] rec A record of IP-Owners table
  # @param [PLinkEdge] l2_edge A Link-edge in layer2 topology (in segment)
  # @return [PNode] Added layer3 node
  def add_l3_node(rec, l2_edge)
    # TODO: l2 node type determination
    l3_node_name = rec.interface =~ /Vlan\d+/ ? "#{rec.node}_#{rec.vrf}" : l2_edge.node
    l3_node = @network.node(l3_node_name)
    l3_node.supports.push([@layer2p.name, l2_edge.node])
    l3_node
  end

  # @param [IPOwnersTableRecord] rec A record of IP-Owners table
  # @param [PNode] l3_node layer3 node to add term-point
  # @param [PLinkEdge] l2_edge A Link-edge in layer2 topology (in segment)
  # @return [PTermPoint] Added layer3 term-point
  def add_l3_tp(rec, l3_node, l2_edge)
    l3_tp = l3_node.term_point(rec.interface)
    l3_tp.supports.push([@layer2p.name, l2_edge.node, l2_edge.tp])
    l3_tp.attribute = { ip_addrs: [rec.ip] }
    l3_tp
  end

  # @param [PLinkEdge] l2_edge A Link-edge in layer2 topology (in segment)
  # @return [Array<(PNode, PTermPoint)>] Added L3-Node and term-point pair
  def add_l3_node_tp(l2_edge)
    rec = @ip_owners.find_record_by_node_intf(l2_edge.node, l2_edge.tp)
    return [nil, nil] unless rec

    l3_node = add_l3_node(rec, l2_edge)
    l3_tp = add_l3_tp(rec, l3_node, l2_edge)
    [l3_node, l3_tp]
  end

  # rubocop:disable Metrics/AbcSize
  # Connect L3 segment-node and host-node
  # @param [PNode] l3_seg_node Layer3 segment-node
  # @param [PNode] l3_node Layer3 (host) node
  # @param [PTermPoint] l3_tp Layer3 (host) port on l3_node
  # @param [PLinkEdge] l2_edge A Link-edge in layer2 topology (in segment)
  def add_l3_link(l3_seg_node, l3_node, l3_tp, l2_edge)
    link = @layer2p.find_link_by_src_edge(l2_edge)
    l3_seg_tp_name = link ? link.dst.tp : l3_seg_node.auto_tp_name
    l3_seg_tp = l3_seg_node.term_point(l3_seg_tp_name)
    l3_seg_tp.supports.push([@layer2p.name, link.dst.node, link.dst.tp])
    @network.link(l3_seg_node.name, l3_seg_tp.name, l3_node.name, l3_tp.name)
  end
  # rubocop:enable Metrics/AbcSize

  # Add all layer3 node, tp and link
  def add_l3_node_tp_link
    @segments.each_with_index do |segment, i|
      # segment: Array(PLinkEdge)
      l3_seg_node = @network.node("Seg#{i}")
      segment.each do |l2_edge|
        l3_seg_node.supports.push([@layer2p.name, l2_edge.node])
        l3_node, l3_tp = add_l3_node_tp(l2_edge)
        next if l3_node.nil? || l3_tp.nil?

        add_l3_link(l3_seg_node, l3_node, l3_tp, l2_edge)
      end
    end
  end

  # rubocop:disable Metrics/AbcSize
  # Recursive exploration: layer2-connected objects
  # @param [PLinkEdge] src_edge A link-edge to specify start point
  def recursively_explore_l3_segment(src_edge)
    @segments.current_segment.push(src_edge)
    src_node = @layer2p.find_node_by_name(src_edge.node)

    src_node.tps_without(src_edge.tp).each do |src_tp|
      src_edge = PLinkEdge.new(src_node.name, src_tp.name)
      link = @layer2p.find_link_by_src_edge(src_edge)
      next if !link || @segments.current_segment_include?(link.dst) # loop avoidance

      @segments.current_segment.push(src_edge)
      recursively_explore_l3_segment(link.dst)
    end
  end
  # rubocop:enable Metrics/AbcSize

  # @param [PLinkEdge] src_edge A link-edge (source)
  # @return [PLinkEdge] Destination link-edge layer2 connected with src_edge
  def dst_edge_connected_with(src_edge)
    return if @segments.exist_segment_includes?(src_edge)

    link = @layer2p.find_link_by_src_edge(src_edge)
    return unless link

    link.dst
  end

  # Convert a link edge (source) to source-destination link-edge pair
  # @param [PNode] src_node Source node
  # @param [PTermPoint] src_tp Source tp
  # @return [Array<PLinkEdge>] Source/destination link-edge pair (layer2 link edge pair)
  def link_edges_by_src(src_node, src_tp)
    src_edge = PLinkEdge.new(src_node.name, src_tp.name)
    dst_edge = dst_edge_connected_with(src_edge)
    [src_edge, dst_edge]
  end

  # rubocop:disable Metrics/MethodLength
  # Explore layer2-connected nodes as "segment" for each node.
  def explore_l3_segment
    @segments = L3SegmentLedger.new
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
  end
  # rubocop:enable Metrics/MethodLength
end
