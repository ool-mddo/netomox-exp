# frozen_string_literal: true

require_relative '../bf_common/pseudo_model'
require_relative 'csv/sw_vlan_props_table'
require_relative 'csv/node_props_table'

# L2 data builder for L1-edge config check
class L2DataChecker < DataBuilderBase
  # @param [String] target Target network (config) data name
  def initialize(target:, debug: false)
    super(debug: debug)
    @node_props = NodePropsTable.new(target)
    @sw_vlan_props = SwitchVlanPropsTable.new(target)
  end

  protected

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

  private

  # @param [InterfacePropertiesTableRecord] tp_prop Term-point property
  # @return [nil, InterfacePropertiesTableRecord] Term-point property
  def choose_tp_prop(tp_prop)
    # NOTICE: if edge node is juniper device, use interface unit config instead of physical.
    node_prop = @node_props.find_record_by_node(tp_prop.node)
    raise StandardError, "Node props not found: #{tp_prop}" unless node_prop

    node_prop.juniper? ? find_unit_prop_by_phy_prop(tp_prop) : tp_prop
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

  # @param [InterfacePropertiesTableRecord] src_tp_prop Term-point properties of source
  # @param [InterfacePropertiesTableRecord] dst_tp_prop Term-point properties of destination
  # @return [Hash] L2 config data for access-port
  def port_l2_config_access(src_tp_prop, dst_tp_prop)
    {
      type: :access,
      src_vlan_id: access_port_vlan_id(src_tp_prop),
      dst_vlan_id: access_port_vlan_id(dst_tp_prop),
      src_tp_prop: src_tp_prop,
      dst_tp_prop: dst_tp_prop
    }
  end

  # @param [InterfacePropertiesTableRecord] src_tp_prop Term-point properties of source
  # @param [InterfacePropertiesTableRecord] dst_tp_prop Term-point properties of destination
  # @return [Hash] L2 config data for trunk-port
  def port_l2_config_trunk(src_tp_prop, dst_tp_prop)
    {
      type: :trunk,
      # common vlan_ids in allowed vlans of src/dst port and src/dst switch vlans
      vlan_ids: operative_trunk_vlans(src_tp_prop, dst_tp_prop),
      src_tp_prop: src_tp_prop,
      dst_tp_prop: dst_tp_prop
    }
  end
end
