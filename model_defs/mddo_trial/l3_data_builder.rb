# frozen_string_literal: true

require_relative 'l3_data_checker'
require_relative 'csv/ip_owners_table'

# L3 data builder
class L3DataBuilder < L3DataChecker
  # @param [String] target Target network (config) data name
  # @param [PNetwork] layer2p Layer2 network topology
  def initialize(target:, layer2p:, debug: false)
    super(layer2p: layer2p, debug: debug)
    @ip_owners = IPOwnersTable.new(target)
  end

  # @return [PNetworks] Networks contains only layer3 network topology
  def make_networks
    @network = @networks.network('layer3')
    @network.type = Netomox::NWTYPE_L3
    explore_l3_segment
    add_l3_node_tp_link
    @networks
  end

  private

  # @param [IPOwnersTableRecord] rec A record of IP-Owners table
  # @param [PNode] l2_node A layer2 node
  # @return [String] Name of layer3 node
  def l3_node_name(rec, l2_node)
    if rec.interface =~ /Vlan\d+/
      rec.vrf == 'default' ? rec.node : "#{rec.node}_#{rec.vrf}"
    else
      l2_node.attribute[:name]
    end
  end

  # @param [IPOwnersTableRecord] rec A record of IP-Owners table
  # @param [PNode] l2_node A layer2 node
  # @return [PNode] Added layer3 node
  def add_l3_node(rec, l2_node)
    # TODO: l2 node type determination
    l3_node = @network.node(l3_node_name(rec, l2_node))
    l3_node.supports.push([@layer2p.name, l2_node.name])
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
    l2_node = @layer2p.node(l2_edge.node)
    rec = @ip_owners.find_record_by_node_intf(l2_node.attribute[:name], l2_edge.tp)
    # if rec not found, search virtual node (GRT/VRF)
    # TODO: using mgmt_vid field temporary
    rec ||= @ip_owners.find_vlan_intf_record_by_node(l2_node.attribute[:name], l2_node.attribute[:mgmt_vid])
    debug_print "  l2_edge=#{l2_edge}, rec=#{rec}"

    return [nil, nil] unless rec

    l3_node = add_l3_node(rec, l2_node)
    l3_tp = add_l3_tp(rec, l3_node, l2_edge)
    [l3_node, l3_tp]
  end

  # @param [PNode] l3_seg_node Layer3 segment-node
  # @param [PLink] l2_link Layer2 link
  # @param [PNode] l3_node Layer3 node
  # @param [PTermPoint] l3_tp Layer3 term-point
  # @return [String] Term-point name
  def l3_seg_tp_name(l3_seg_node, l2_link, l3_node, l3_tp)
    l2_dst_node = @layer2p.node(l2_link.dst.node)
    tp_name = l2_link ? "#{l2_dst_node.attribute[:name]}_#{l2_link.dst.tp}" : l3_seg_node.auto_tp_name
    tp_name = "#{l3_node.name}_#{l3_tp.name}" if l3_tp.name =~ /Vlan\d+/
    tp_name
  end

  # rubocop:disable Metrics/AbcSize

  # Connect L3 segment-node and host-node
  # @param [PNode] l3_seg_node Layer3 segment-node
  # @param [PNode] l3_node Layer3 (host) node
  # @param [PTermPoint] l3_tp Layer3 (host) port on l3_node
  # @param [PLinkEdge] l2_edge A Link-edge in layer2 topology (in segment)
  # @return [void]
  def add_l3_link(l3_seg_node, l3_node, l3_tp, l2_edge)
    l2_link = @layer2p.find_link_by_src_edge(l2_edge)
    l3_seg_tp = l3_seg_node.term_point(l3_seg_tp_name(l3_seg_node, l2_link, l3_node, l3_tp))
    l3_seg_tp.supports.push([@layer2p.name, l2_link.dst.node, l2_link.dst.tp])
    debug_print "  link: #{l3_seg_node.name}, #{l3_seg_tp.name}, #{l3_node.name}, #{l3_tp.name}"
    @network.link(l3_seg_node.name, l3_seg_tp.name, l3_node.name, l3_tp.name)
    @network.link(l3_node.name, l3_tp.name, l3_seg_node.name, l3_seg_tp.name) # bidirectional
  end
  # rubocop:enable Metrics/AbcSize

  # rubocop:disable Metrics/MethodLength

  # Add all layer3 node, tp and link
  # @return [void]
  def add_l3_node_tp_link
    @segments.each_with_index do |segment, i|
      # segment: Array(PLinkEdge)
      l3_seg_node = @network.node("Seg#{i}")
      debug_print "* Start L3 topology: Segment #{i}"
      segment.each do |l2_edge|
        l3_seg_node.supports.push([@layer2p.name, l2_edge.node])
        l3_node, l3_tp = add_l3_node_tp(l2_edge)
        if l3_node.nil? || l3_tp.nil?
          warn "# WARNING: Can not link #{l3_seg_node.name} > #{l2_edge}"
          next
        end

        add_l3_link(l3_seg_node, l3_node, l3_tp, l2_edge)
      end
    end
  end
  # rubocop:enable Metrics/MethodLength
end
