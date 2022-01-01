# frozen_string_literal: true

require_relative 'l2_data_checker'
require_relative 'csv/interface_prop_table'

# rubocop:disable Metrics/ClassLength

# L2 data builder
class L2DataBuilder < L2DataChecker
  # @param [String] target Target network (config) data name
  # @param [PNetwork] layer1p Layer1 network topology
  def initialize(target:, layer1p:, debug: false)
    super(target: target, debug: debug)
    @layer1p = layer1p
    @intf_props = InterfacePropertiesTable.new(target)
  end

  # @return [PNetworks] Networks contains only layer2 network topology
  def make_networks
    @network = @networks.network('layer2')
    @network.type = Netomox::NWTYPE_MDDO_L2
    @network.supports.push(@layer1p.name)
    setup_nodes_and_links
    @networks
  end

  private

  # @param [InterfacePropertiesTableRecord] phy_prop Intf property of physical intf
  # @param [Array<InterfacePropertiesTableRecord>] unit_props Unit interface properties of phy_intf
  # @return [InterfacePropertiesTableRecord] Phy. interface property (as trunk port)
  def junos_trunk_port_as_subif(phy_prop, unit_props)
    # NOTICE: L3 sub-interface : batfish cannot handle sub-interface vlan configuration
    #   here, it assumes that unit-number is vlan-id
    phy_prop.allowed_vlans = unit_props.map(&:unit_number).map(&:to_i)
    phy_prop.switchport = 'True'
    phy_prop.switchport_mode = 'TRUNK'
    phy_prop
  end

  # for junos: physical-interface <> its unit matching
  # @param [InterfacePropertiesTableRecord] phy_prop Physical interface property
  # @return [nil, InterfacePropertiesTableRecord] interface unit property
  # @raise [StandardError] If unit interface is not found
  def find_unit_prop_by_phy_prop(phy_prop)
    unit_props = @intf_props.find_all_unit_records_by_node_intf(phy_prop.node, phy_prop.interface)
    if unit_props.length == 1
      unit_props[0]
    elsif unit_props.length > 1
      junos_trunk_port_as_subif(phy_prop, unit_props)
    else
      raise StandardError("Interface unit not found : #{phy_prop}")
    end
  end

  # @param [PNode] l1_node A node under the new layer2 node
  # @param [Integer] vlan_id VLAN id (if used)
  # @param [InterfacePropertiesTableRecord] tp_prop Layer1 (phy) or unit interface property
  # @return [String] Suffix string for Layer2 node name
  def l2_node_name_suffix(l1_node, vlan_id, tp_prop)
    return tp_prop.interface unless vlan_id.positive?
    # Junos-style sub-interface
    # NOTICE: "unit number = vlan-id" assumption
    return "#{tp_prop.interface}.#{vlan_id}" if juniper_node?(l1_node)

    "Vlan#{vlan_id}" # Cisco-IOS-style (SVI)
  end

  # @param [PNode] l1_node A node under the new layer2 node
  # @param [Integer] vlan_id VLAN id (if used)
  # @param [InterfacePropertiesTableRecord] tp_prop Layer1 (phy) or unit interface property
  # @return [String] Name of layer2 node
  def l2_node_name(l1_node, vlan_id, tp_prop)
    "#{l1_node.name}_#{l2_node_name_suffix(l1_node, vlan_id, tp_prop)}"
  end

  # @param [PNode] l1_node A node under the new layer2 node
  # @param [Integer] vlan_id VLAN id (if used)
  # @param [InterfacePropertiesTableRecord] tp_prop Layer1 (phy) or unit interface property
  # @return [PNode] Added layer2 node
  def add_l2_node(l1_node, vlan_id, tp_prop)
    new_node = @network.node(l2_node_name(l1_node, vlan_id, tp_prop))
    new_node.attribute = { name: l1_node.name, vlan_id: vlan_id }
    new_node.supports.push([@layer1p.name, l1_node.name])
    new_node
  end

  # @param [PNode] l1_node A node under the new layer2 node
  # @param [Integer] vlan_id VLAN id (if used)
  # @return [Boolean] True if L3 sub-intf of junos
  def junos_l3_sub_interface?(l1_node, vlan_id)
    vlan_id.positive? && juniper_node?(l1_node)
  end

  # @param [PNode] l1_node A node under the new layer2 node
  # @param [Integer] vlan_id VLAN id (if used)
  # @param [InterfacePropertiesTableRecord] tp_prop Layer1 (phy) or unit interface property
  # @return [String] Name of layer2 term-point
  def l2_tp_name(l1_node, vlan_id, tp_prop)
    if junos_l3_sub_interface?(l1_node, vlan_id)
      # for Junos L3 sub-interface (unit number = vlan-id rule)
      tp_prop.interface + ".#{vlan_id}"
    else
      tp_prop.interface
    end
  end

  # @param [PNode] l1_node layer1 node under l2_node
  # @param [PTermPoint] l1_tp layer1 term-point under the new layer2 term-point
  # @param [InterfacePropertiesTableRecord] l1_tp_prop Layer1 (phy) interface property
  # return [Array<Array<String>>] Support node/tp data
  def l2_tp_supports(l1_node, l1_tp, l1_tp_prop)
    if l1_tp_prop.lag_parent?
      l1_tp_prop.lag_member_interfaces.map { |intf| [@layer1p.name, l1_node.name, intf] }
    else
      [[@layer1p.name, l1_node.name, l1_tp.name]]
    end
  end

  # @param [PNode] l1_node layer1 node under l2_node
  # @param [Integer] vlan_id
  # @param [InterfacePropertiesTableRecord] tp_prop Layer1 (phy) or unit interface property
  def l2_tp_attribute(l1_node, vlan_id, tp_prop)
    swp_mode = junos_l3_sub_interface?(l1_node, vlan_id) ? 'trunk' : tp_prop.switchport_mode.downcase
    {
      description: tp_prop.description,
      switchport_mode: swp_mode,
      encapsulation: swp_mode == 'trunk' ? tp_prop.switchport_trunk_encapsulation.downcase : ''
    }
  end

  # @param [PNode] l2_node Layer2 node to add new term-point
  # @param [PNode] l1_node layer1 node under l2_node
  # @param [PTermPoint] l1_tp layer1 term-point under the new layer2 term-point
  # @param [Integer] vlan_id VLAN id (if used)
  # @param [InterfacePropertiesTableRecord] tp_prop Layer1 (phy) or unit interface property
  # @return [PTermPoint] Added layer2 term-point
  # @raise [StandardError] if layer1 term-point property is not found
  def add_l2_tp(l2_node, l1_node, l1_tp, vlan_id, tp_prop)
    new_tp = l2_node.term_point(l2_tp_name(l1_node, vlan_id, tp_prop))
    l1_tp_prop = @intf_props.find_record_by_node_intf(l1_node.name, l1_tp.name)
    raise StandardError, "Layer1 term-point property not found: #{l1_node.name}[#{l1_tp.name}]" unless l1_tp_prop

    new_tp.supports.push(*l2_tp_supports(l1_node, l1_tp, l1_tp_prop))
    new_tp.attribute = l2_tp_attribute(l1_node, vlan_id, tp_prop)
    new_tp
  end

  # @param [PNode] l1_node A node under the new layer2 node
  # @param [PTermPoint] l1_tp Layer1 term-point under the new layer2 term-point
  # @param [Integer] vlan_id vlan_id VLAN id (if used)
  # @param [InterfacePropertiesTableRecord] tp_prop Layer1 (phy) or unit interface property
  # @return [Array(PNode, PTermPoint)] A pair of added node name and tp name
  def add_l2_node_tp(l1_node, l1_tp, vlan_id, tp_prop)
    new_node = add_l2_node(l1_node, vlan_id, tp_prop)
    new_tp = add_l2_tp(new_node, l1_node, l1_tp, vlan_id, tp_prop)
    [new_node, new_tp]
  end

  # rubocop:disable Metrics/ParameterLists

  # @param [PNode] src_node Link source node
  # @param [PTermPoint] src_tp Link source tp (on src_node)
  # @param [Integer] src_vlan_id VLAN id of src_tp
  # @param [PNode] dst_node Link destination node
  # @param [PTermPoint] dst_tp link destination port (on dst_node)
  # @param [Integer] dst_vlan_id VLAN id of dst_tp
  # @return [void]
  def add_l2_node_tp_link(src_node, src_tp, src_vlan_id, src_tp_prop, dst_node, dst_tp, dst_vlan_id, dst_tp_prop)
    src_l2_node, src_l2_tp = add_l2_node_tp(src_node, src_tp, src_vlan_id, src_tp_prop).map(&:name)
    dst_l2_node, dst_l2_tp = add_l2_node_tp(dst_node, dst_tp, dst_vlan_id, dst_tp_prop).map(&:name)
    # NOTE: Layer2 link is added according to layer1 link.
    # Therefore, layer1 link is bidirectional, layer2 is same
    debug_print "  Add L2 ink: #{src_l2_node}[#{src_l2_tp}] > #{dst_l2_node}[#{dst_l2_tp}]"
    @network.link(src_l2_node, src_l2_tp, dst_l2_node, dst_l2_tp)
  end
  # rubocop:enable Metrics/ParameterLists

  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize

  # @param [PNode] src_node Link source node
  # @param [PTermPoint] src_tp Link source tp (on src_node)
  # @param [PNode] dst_node Link destination node
  # @param [PTermPoint] dst_tp link destination port (on dst_node)
  # @param [Hash] check_result L2 config check result (@see: port_l2_config_check)
  # @return [void]
  def add_l2_node_tp_link_by_config(src_node, src_tp, dst_node, dst_tp, check_result)
    case check_result[:type]
    when :access
      add_l2_node_tp_link(
        src_node, src_tp, check_result[:src_vlan_id], check_result[:src_tp_prop],
        dst_node, dst_tp, check_result[:dst_vlan_id], check_result[:dst_tp_prop]
      )
    when :trunk
      check_result[:vlan_ids].each do |vlan_id|
        add_l2_node_tp_link(src_node, src_tp, vlan_id, check_result[:src_tp_prop],
                            dst_node, dst_tp, vlan_id, check_result[:dst_tp_prop])
      end
    else
      # type: :error
      add_l2_node_tp(src_node, src_tp, 0, check_result[:src_tp_prop])
      add_l2_node_tp(dst_node, dst_tp, 0, check_result[:dst_tp_prop])
      warn "Warning: #{check_result[:message]}"
    end
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

  # @param [String] lag_tp_name Layer1 LAG (parent) term-point name
  # @param [PTermPoint] member_tp Layer1 LAG member term-point name
  # @return [PTermPoint] LAG (parent) term-point
  def make_l1_lag_tp(lag_tp_name, member_tp)
    l1_lag_tp = PTermPoint.new(lag_tp_name)
    l1_lag_tp.attribute = member_tp.attribute
    l1_lag_tp.supports = member_tp.supports
    l1_lag_tp
  end

  # @param [PLinkEdge] link_edge A Link-edge to get interface property
  # @return [Array(PNode, PTermPoint, InterfacePropertiesTableRecord)]
  #   Node, interface, interface property of the edge
  # @raise [StandardError] if term-point props of the link-edge is not found
  def tp_prop_by_link_edge(link_edge)
    node = @layer1p.find_node_by_name(link_edge.node)
    tp = node.find_tp_by_name(link_edge.tp)
    tp_prop = @intf_props.find_record_by_node_intf(node.name, tp.name)
    raise StandardError, "Term point not found: #{link_edge}" unless tp_prop

    [
      node,
      tp_prop.lag_member? ? make_l1_lag_tp(tp_prop.lag_parent_interface, tp) : tp,
      tp_prop.lag_member? ? @intf_props.find_record_by_node_intf(node.name, tp_prop.lag_parent_interface) : tp_prop
    ]
  end

  # @return [void]
  def setup_nodes_and_links
    @layer1p.links.each do |link|
      debug_print "* L1 link = #{link}"
      src_node, src_tp, src_tp_prop = tp_prop_by_link_edge(link.src)
      dst_node, dst_tp, dst_tp_prop = tp_prop_by_link_edge(link.dst)
      check_result = port_l2_config_check(src_node, src_tp_prop, dst_node, dst_tp_prop)
      debug_print "  check_result = #{check_result}"
      add_l2_node_tp_link_by_config(src_node, src_tp, dst_node, dst_tp, check_result)
    end
  end
end
# rubocop:enable Metrics/ClassLength
