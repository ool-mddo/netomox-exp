# frozen_string_literal: true

require_relative 'pseudo_dsl/pseudo_model'
require_relative 'csv_mapper/sw_vlan_props_table'

module TopologyBuilder
  # rubocop:disable Metrics/ClassLength

  # L2 data builder for L1-edge config check
  class L2DataChecker < PseudoDSL::DataBuilderBase
    # @param [String] target Target network (config) data name
    def initialize(target:, debug: false)
      super(debug: debug)
      @sw_vlan_props = CSVMapper::SwitchVlanPropsTable.new(target)
    end

    protected

    # rubocop:disable Metrics/MethodLength

    # @param [PNode] src_node Source layer1 node
    # @param [InterfacePropertiesTableRecord] src_tp_prop Term-point properties of source
    # @param [PNode] dst_node Destination layer1 node
    # @param [InterfacePropertiesTableRecord] dst_tp_prop Term-point properties of destination
    # @return [Hash] L2 config data for trunk-port
    def port_l2_config_check(src_node, src_tp_prop, dst_node, dst_tp_prop)
      target_src_tp_prop = choose_tp_prop(src_node, src_tp_prop)
      target_dst_tp_prop = choose_tp_prop(dst_node, dst_tp_prop)
      if target_src_tp_prop.nil? || target_dst_tp_prop.nil?
        return {
          type: :error,
          src_tp_prop: target_src_tp_prop || src_tp_prop,
          dst_tp_prop: target_dst_tp_prop || dst_tp_prop,
          message: "Term-point props not found: #{target_src_tp_prop} or #{target_dst_tp_prop}"
        }
      end

      if operative_access_port?(target_src_tp_prop, target_dst_tp_prop)
        debug_print "  operative access port: src_tpp:#{target_src_tp_prop}, dst_tpp:#{target_dst_tp_prop}"
        port_l2_config_access(target_src_tp_prop, target_dst_tp_prop)
      elsif operative_trunk_port?(target_src_tp_prop, target_dst_tp_prop)
        debug_print "  operative trunk port: src_tpp:#{target_src_tp_prop}, dst_tpp:#{target_dst_tp_prop}"
        port_l2_config_trunk(src_node, target_src_tp_prop, dst_node, target_dst_tp_prop)
      else
        {
          type: :error,
          src_tp_prop: target_src_tp_prop,
          dst_tp_prop: target_dst_tp_prop,
          message: 'L2 term-point config mismatch: ' \
                   "#{target_src_tp_prop.node}[#{target_src_tp_prop.interface}], " \
                   "#{target_dst_tp_prop.node}[#{target_dst_tp_prop.interface}]"
        }
      end
    end
    # rubocop:enable Metrics/MethodLength

    private

    # Overwrite physical-interface-property vlan information
    # @param [InterfacePropertiesTableRecord] phy_prop Intf property of physical intf
    # @param [Array<InterfacePropertiesTableRecord>] unit_props Unit interface properties of phy_intf
    # @return [InterfacePropertiesTableRecord] Phy. interface property (as trunk port)
    def change_property_as_trunk(phy_prop, unit_props)
      debug_print "    unit_props: #{unit_props}"
      # NOTICE: L3 sub-interface : use encapsulation_vlan as vlan-id of the unit-interface
      phy_prop.allowed_vlans = unit_props.map(&:encapsulation_vlan)
      debug_print "    junos trunk port subif: phy:#{phy_prop}, allowed_vlans:#{phy_prop.allowed_vlans}"
      phy_prop.switchport = 'True'
      phy_prop.switchport_mode = 'TRUNK'
      phy_prop
    end

    # for junos: physical-interface <> its unit matching
    # @param [InterfacePropertiesTableRecord] phy_prop Physical interface property
    # @return [nil, InterfacePropertiesTableRecord] interface unit property
    def find_unit_prop_by_phy_prop(phy_prop)
      unit_props = @intf_props.find_all_unit_records_by_node_intf(phy_prop.node, phy_prop.interface)
      debug_print "  find_unit_props (junos) #{phy_prop.node}[#{phy_prop.interface}]: #{unit_props.map(&:interface)}"

      if unit_props.length == 1 && !unit_props[0].l3_subif?
        # (only) one unit of L3 interface: usually unit:0
        unit_props[0]
      elsif unit_props.all?(&:l3_subif?)
        # it seems layer3-sub-interface:
        change_property_as_trunk(phy_prop, unit_props)
      else
        raise StandardError, "Unknown unit interface type: #{phy_prop.node}[#{phy_prop.interface}]"
      end
    end

    # @param [PNode] l1_node Layer1 node
    # @return [Boolean] True if the node os-type is juniper
    def juniper_node?(l1_node)
      l1_node.attribute[:os_type].downcase == 'juniper'
    end

    # @param [PNode] l1_node Layer1 node
    # @param [InterfacePropertiesTableRecord] tp_prop Term-point property
    # @return [nil, InterfacePropertiesTableRecord] Term-point property
    def choose_tp_prop(l1_node, tp_prop)
      # NOTICE: if edge node is juniper device, use interface unit config instead of physical.
      debug_print "  l1 node #{l1_node.name} is juniper? : #{juniper_node?(l1_node)}"
      juniper_node?(l1_node) ? find_unit_prop_by_phy_prop(tp_prop) : tp_prop
    end

    # Vlan-id list in switch (it has interface of tp_prop)
    # @param [PNode] l1_node Layer1 node
    # @param [InterfacePropertiesTableRecord] tp_prop A record of term-point properties table
    # @return [Array<Integer>] List of vlan-id
    def sw_vlans(l1_node, tp_prop)
      vlans = @sw_vlan_props.find_all_records_by_node_intf(l1_node.name, tp_prop.interface).map(&:vlan_id).uniq
      # NOTICE: junos L3 sub-interface vlan is used `encapsulation_vlan` column
      vlans = tp_prop.allowed_vlans if vlans.empty? && juniper_node?(l1_node)
      vlans
    end

    # Check port vlan config and switch vlan config to determine it is operative.
    # @param [PNode] src_node Source layer1 node
    # @param [InterfacePropertiesTableRecord] src_tp_prop Term-point properties of source
    # @param [PNode] dst_node Destination layer1 node
    # @param [InterfacePropertiesTableRecord] dst_tp_prop Term-point properties of destination
    # @return [Array<Integer>] A list of vlan-id (common-set of each port/node)
    def operative_trunk_vlans(src_node, src_tp_prop, dst_node, dst_tp_prop)
      debug_print "  src #{src_node.name}[#{src_tp_prop.interface}]: " \
                  "operative_vlans: #{src_tp_prop.allowed_vlans}, #{sw_vlans(src_node, src_tp_prop)}"
      debug_print "  dst #{dst_node.name}[#{dst_tp_prop.interface}]: " \
                  "operative_vlans: #{dst_tp_prop.allowed_vlans}, #{sw_vlans(dst_node, dst_tp_prop)}"
      src_tp_prop.allowed_vlans & # allowed-vlans on port
        sw_vlans(src_node, src_tp_prop) & # vlans on device
        dst_tp_prop.allowed_vlans & # allowed-vlans on port
        sw_vlans(dst_node, dst_tp_prop) # vlans on device
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
      src_tp_prop.swp_trunk? && dst_tp_prop.swp_trunk? && src_tp_prop.trunk_encap == dst_tp_prop.trunk_encap
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

    # @param [PNode] src_node Source layer1 node
    # @param [InterfacePropertiesTableRecord] src_tp_prop Term-point properties of source
    # @param [PNode] dst_node Destination layer1 node
    # @param [InterfacePropertiesTableRecord] dst_tp_prop Term-point properties of destination
    # @return [Hash] L2 config data for trunk-port
    def port_l2_config_trunk(src_node, src_tp_prop, dst_node, dst_tp_prop)
      {
        type: :trunk,
        # common vlan_ids in allowed vlans of src/dst port and src/dst switch vlans
        vlan_ids: operative_trunk_vlans(src_node, src_tp_prop, dst_node, dst_tp_prop),
        src_tp_prop: src_tp_prop,
        dst_tp_prop: dst_tp_prop
      }
    end
  end
  # rubocop:enable Metrics/ClassLength
end
