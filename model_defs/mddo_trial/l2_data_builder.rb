# frozen_string_literal: true

require_relative '../bf_common/pseudo_model'
require_relative 'csv/sw_vlan_props_table'
require_relative 'csv/interface_prop_table'
require_relative 'csv/node_props_table'

# rubocop:disable Metrics/ClassLength

# L2 data builder
class L2DataBuilder < DataBuilderBase
  # @param [String] target Target network (config) data name
  # @param [PNetwork] layer1p Layer1 network topology
  def initialize(target:, layer1p:, debug: false)
    super(debug: debug)
    @layer1p = layer1p
    @sw_vlan_props = SwitchVlanPropsTable.new(target)
    @intf_props = InterfacePropertiesTable.new(target)
    @node_props = NodePropsTable.new(target)
  end

  # @return [PNetworks] Networks contains only layer2 network topology
  def make_networks
    @network = @networks.network('layer2')
    @network.type = Netomox::NWTYPE_L2
    @network.supports.push(@layer1p.name)
    setup_nodes_and_links
    @networks
  end

  private

  # @param [InterfacePropertiesTableRecord] tp_prop A record of term-point properties table
  #   (for routed or access-vlan port)
  # @return [Integer] Vlan-id if the record has access_vlan info, or 0 (no access_vlan)
  def access_port_vlan_id(tp_prop)
    # 0:routed port (not specified vlan)
    tp_prop.swp_access? ? tp_prop.access_vlan : 0
  end

  # Check port vlan config and switch vlan config to determine it is operative.
  # @param [InterfacePropertiesTableRecord] tp_prop A record of term-point properties table
  #   (for routed or access-vlan port)
  # @return [Integer] Vlan-id or 0 (no access_vlan)
  def operative_access_vlan(tp_prop)
    return 0 if tp_prop.routed_port? # NOP for routed port

    found_sw_vlan_prop = @sw_vlan_props.find_record_by_node_intf(tp_prop.node, tp_prop.interface)
    # -1:vlan bridge doesn't exists
    found_sw_vlan_prop ? found_sw_vlan_prop.vlan_id : -1
  end

  # Vlan-id list in switch (it has interface of tp_prop)
  # @param [InterfacePropertiesTableRecord] tp_prop A record of term-point properties table
  # @return [Array<Integer>] List of vlan-id
  def sw_vlans(tp_prop)
    vlans = @sw_vlan_props.find_all_records_by_node_intf(tp_prop.node, tp_prop.interface).map(&:vlan_id).uniq
    if vlans.empty?
      # NOTICE: Batfish cannot handle vlan information with vlan sub-interface (in junos, probably ios...)
      #   So, then it assumes that switch vlans = trunk allowed vlans
      node_prop = @node_props.find_record_by_node(tp_prop.node)
      vlans = tp_prop.allowed_vlans if node_prop&.juniper?
    end
    vlans
  end

  # Check access-port vlan config between layer1-connected port/node.
  # @param [InterfacePropertiesTableRecord] src_tp_prop Term-point properties of source
  # @param [InterfacePropertiesTableRecord] dst_tp_prop Term-point properties of destination
  # @return [Boolean] true if vlan-config are operative
  def operative_access_port?(src_tp_prop, dst_tp_prop)
    # for routed/access port pair, vlan-id matching is unnecessary. (untag port)
    src_tp_prop.almost_access? &&
      access_port_vlan_id(src_tp_prop) == operative_access_vlan(src_tp_prop) && # on device?
      dst_tp_prop.almost_access? &&
      access_port_vlan_id(dst_tp_prop) == operative_access_vlan(dst_tp_prop) # on device?
  end

  # Check trunk-port vlan config between layer1-connected port/node
  # @param [InterfacePropertiesTableRecord] src_tp_prop Term-point properties of source
  # @param [InterfacePropertiesTableRecord] dst_tp_prop Term-point properties of destination
  # @return [Boolean] true if vlan-config are operative
  def operative_trunk_port?(src_tp_prop, dst_tp_prop)
    src_tp_prop.swp_trunk? && dst_tp_prop.swp_trunk?
  end

  # Check port vlan config and switch vlan config to determine it is operative.
  # @param [InterfacePropertiesTableRecord] src_tp_prop Term-point properties of source
  # @param [InterfacePropertiesTableRecord] dst_tp_prop Term-point properties of destination
  # @return [Array<Integer>] A list of vlan-id (common-set of each port/node)
  def operative_trunk_vlans(src_tp_prop, dst_tp_prop)
    debug_print "  src #{src_tp_prop.node}[#{src_tp_prop.interface}]: " \
                "operative_vlans: #{src_tp_prop.allowed_vlans}, #{sw_vlans(src_tp_prop)}"
    debug_print "  dst #{dst_tp_prop.node}[#{dst_tp_prop.interface}]: " \
                "operative_vlans: #{dst_tp_prop.allowed_vlans}, #{sw_vlans(dst_tp_prop)}"
    src_tp_prop.allowed_vlans & # allowed-vlans on port
      sw_vlans(src_tp_prop) & # vlans on device
      dst_tp_prop.allowed_vlans & # allowed-vlans on port
      sw_vlans(dst_tp_prop) # vlans on device
  end

  # @param [InterfacePropertiesTableRecord] src_tp_prop Term-point properties of source
  # @param [InterfacePropertiesTableRecord] dst_tp_prop Term-point properties of destination
  # @return [Hash] L2 config data for access-port
  def port_l2_config_access(src_tp_prop, dst_tp_prop)
    {
      type: :access,
      src_vlan_id: access_port_vlan_id(src_tp_prop),
      dst_vlan_id: access_port_vlan_id(dst_tp_prop)
    }
  end

  # @param [InterfacePropertiesTableRecord] src_tp_prop Term-point properties of source
  # @param [InterfacePropertiesTableRecord] dst_tp_prop Term-point properties of destination
  # @return [Hash] L2 config data for trunk-port
  def port_l2_config_trunk(src_tp_prop, dst_tp_prop)
    {
      type: :trunk,
      # common vlan_ids in allowed vlans of src/dst port and src/dst switch vlans
      vlan_ids: operative_trunk_vlans(src_tp_prop, dst_tp_prop)
    }
  end

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

  # @param [InterfacePropertiesTableRecord] tp_prop Term-point property
  # @return [nil, InterfacePropertiesTableRecord] Term-point property
  def choose_tp_prop(tp_prop)
    # NOTICE: if edge node is juniper device, use interface unit config instead of physical.
    node_prop = @node_props.find_record_by_node(tp_prop.node)
    raise StandardError, "Node props not found: #{tp_prop}" unless node_prop

    node_prop.juniper? ? find_unit_prop_by_phy_prop(tp_prop) : tp_prop
  end

  # @param [InterfacePropertiesTableRecord] src_tp_prop Term-point properties of source
  # @param [InterfacePropertiesTableRecord] dst_tp_prop Term-point properties of destination
  # @return [Hash] L2 config data for trunk-port
  def port_l2_config_check(src_tp_prop, dst_tp_prop)
    src_tp_prop = choose_tp_prop(src_tp_prop)
    dst_tp_prop = choose_tp_prop(dst_tp_prop)
    if src_tp_prop.nil? || dst_tp_prop.nil?
      raise StandardError, "Term-point props not found: #{src_tp_prop} or #{dst_tp_prop}"
    end
    return port_l2_config_access(src_tp_prop, dst_tp_prop) if operative_access_port?(src_tp_prop, dst_tp_prop)
    return port_l2_config_trunk(src_tp_prop, dst_tp_prop) if operative_trunk_port?(src_tp_prop, dst_tp_prop)

    { type: :error }
  end

  # @param [PNode] l1_node A node under the new layer2 node
  # @param [PTermPoint] l1_tp Layer1 term-point under the new layer2 term-point
  # @param [Integer] vlan_id VLAN id (if used)
  # @return [PNode] Added layer2 node
  def add_l2_node(l1_node, l1_tp, vlan_id)
    l2_node_name = l1_node.name + (vlan_id.positive? ? "_Vlan#{vlan_id}" : "_#{l1_tp.name}")
    new_node = @network.node(l2_node_name)
    # TODO: using management vlan-id field temporary to keep vlan id of L2 bridge
    new_node.attribute = { name: l1_node.name, mgmt_vid: vlan_id }
    new_node.supports.push([@layer1p.name, l1_node.name])
    new_node
  end

  # rubocop:disable Metrics/AbcSize

  # @param [PNode] l2_node Layer2 node to add new term-point
  # @param [PNode] l1_node layer1 node under l2_node
  # @param [PTermPoint] l1_tp layer1 term-point under the new layer2 term-point
  # @return [PTermPoint] Added layer2 term-point
  def add_l2_tp(l2_node, l1_node, l1_tp)
    new_tp = l2_node.term_point(l1_tp.name)
    l1_tp_prop = @intf_props.find_record_by_node_intf(l1_node.name, l1_tp.name)
    if l1_tp_prop.lag_parent?
      supports = l1_tp_prop.lag_member_interfaces.map { |intf| [@layer1p.name, l1_node.name, intf] }
      new_tp.supports.push(*supports)
    else
      new_tp.supports.push([@layer1p.name, l1_node.name, l1_tp.name])
    end
    new_tp
  end
  # rubocop:enable Metrics/AbcSize

  # @param [PNode] l1_node A node under the new layer2 node
  # @param [PTermPoint] l1_tp Layer1 term-point under the new layer2 term-point
  # @param [Integer] vlan_id vlan_id VLAN id (if used)
  # @return [Array<PNode, PTermPoint>] A pair of added node name and tp name
  def add_l2_node_tp(l1_node, l1_tp, vlan_id)
    new_node = add_l2_node(l1_node, l1_tp, vlan_id)
    new_tp = add_l2_tp(new_node, l1_node, l1_tp)
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
  def add_l2_node_tp_link(src_node, src_tp, src_vlan_id, dst_node, dst_tp, dst_vlan_id)
    src_l2_node, src_l2_tp = add_l2_node_tp(src_node, src_tp, src_vlan_id).map(&:name)
    dst_l2_node, dst_l2_tp = add_l2_node_tp(dst_node, dst_tp, dst_vlan_id).map(&:name)
    # NOTE: Layer2 link is added according to layer1 link.
    # Therefore, layer1 link is bidirectional, layer2 is same
    debug_print "  Add L2 ink: #{src_l2_node}[#{src_l2_tp}] > #{dst_l2_node}[#{dst_l2_tp}]"
    @network.link(src_l2_node, src_l2_tp, dst_l2_node, dst_l2_tp)
  end
  # rubocop:enable Metrics/ParameterLists

  # @param [PNode] src_node Link source node
  # @param [PTermPoint] src_tp Link source tp (on src_node)
  # @param [PNode] dst_node Link destination node
  # @param [PTermPoint] dst_tp link destination port (on dst_node)
  # @param [Hash] check_result L2 config check result (@see: port_l2_config_check)
  # @return [void]
  def add_l2_node_tp_link_by_config(src_node, src_tp, dst_node, dst_tp, check_result)
    case check_result[:type]
    when :access
      add_l2_node_tp_link(src_node, src_tp, check_result[:src_vlan_id], dst_node, dst_tp, check_result[:dst_vlan_id])
    when :trunk
      check_result[:vlan_ids].each do |vlan_id|
        add_l2_node_tp_link(src_node, src_tp, vlan_id, dst_node, dst_tp, vlan_id)
      end
    else
      warn '# WARNING: L2 trunk/access mode mismatch'
    end
  end

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
  # @return [(Array<PNode, PTermPoint, InterfacePropertiesTableRecord)>]
  #   Node, interface, interface property of the edge
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
      check_result = port_l2_config_check(src_tp_prop, dst_tp_prop)
      debug_print "  check_result = #{check_result}"
      add_l2_node_tp_link_by_config(src_node, src_tp, dst_node, dst_tp, check_result)
    end
  end
end
# rubocop:enable Metrics/ClassLength
