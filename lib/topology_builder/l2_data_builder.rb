# frozen_string_literal: true

require_relative 'l2_data_checker'
require_relative 'csv_mapper/interface_prop_table'

module NetomoxExp
  module TopologyBuilder
    # rubocop:disable Metrics/ClassLength

    # L2 data builder
    class L2DataBuilder < L2DataChecker
      # @param [String] target Target network (config) data name
      # @param [Netomox::PseudoDSL::PNetwork] layer1p Layer1 network topology
      def initialize(target:, layer1p:, debug: false)
        super(target:, debug:)
        @layer1p = layer1p
        @intf_props = CSVMapper::InterfacePropertiesTable.new(target)
      end

      # @return [Netomox::PseudoDSL::PNetworks] Networks contains only layer2 network topology
      def make_networks
        @network = @networks.network('layer2')
        @network.type = Netomox::NWTYPE_MDDO_L2
        @network.attribute = { name: 'mddo-layer2-network' }
        @network.supports.push(@layer1p.name)
        setup_nodes_and_links
        check_disconnected_node
        add_unlinked_ip_owner_tp
        @networks
      end

      private

      # @param [Netomox::PseudoDSL::PNode] l1_node A node under the new layer2 node
      # @param [InterfacePropertiesTableRecord] l1_tp_prop Layer1 (phy) or unit interface property
      # @param [Integer] vlan_id VLAN id (if used)
      # @return [String] Suffix string for Layer2 node name
      def l2_node_name_suffix(l1_node, l1_tp_prop, vlan_id)
        return l1_tp_prop.interface unless vlan_id.positive?

        if juniper_node?(l1_node)
          # Juniper-Junos-style
          format('vlan%<vlan_id>04d', vlan_id:)
        else
          # Cisco-IOS-style (SVI)
          "Vlan#{vlan_id}"
        end
      end

      # @param [Netomox::PseudoDSL::PNode] l1_node A node under the new layer2 node
      # @param [InterfacePropertiesTableRecord] l1_tp_prop Layer1 (phy) or unit interface property
      # @param [Integer] vlan_id VLAN id (if used)
      # @return [String] Name of layer2 node
      def l2_node_name(l1_node, l1_tp_prop, vlan_id)
        "#{l1_node.name}_#{l2_node_name_suffix(l1_node, l1_tp_prop, vlan_id)}"
      end

      # @param [Netomox::PseudoDSL::PNode] l1_node A node under the new layer2 node
      # @param [InterfacePropertiesTableRecord] l1_tp_prop Layer1 (phy) or unit interface property
      # @param [Integer] vlan_id VLAN id (if used)
      # @return [Netomox::PseudoDSL::PNode] Added layer2 node
      def add_l2_node(l1_node, l1_tp_prop, vlan_id)
        new_node = @network.node(l2_node_name(l1_node, l1_tp_prop, vlan_id))
        new_node.attribute = { name: l1_node.name, vlan_id: }
        # same supports are pushed when vlan bridge node (uniq)
        new_node.supports.push([@layer1p.name, l1_node.name]).uniq!
        new_node
      end

      # for junos: the term-point owns l3-sub-interface(s)
      # @param [Netomox::PseudoDSL::PNode] l1_node A node under the new layer2 node
      # @param [Netomox::PseudoDSL::PTermPoint] l1_tp layer1 term-point under the new layer2 term-point
      # @return [Boolean] True if L3 sub-intf of junos
      def owns_l3_sub_interface?(l1_node, l1_tp)
        juniper_node?(l1_node) && @intf_props.find_all_unit_records_by_node_intf(l1_node.name, l1_tp.name)
                                             .all?(&:l3_subif?)
      end

      # @param [Netomox::PseudoDSL::PNode] l1_node A node under the new layer2 node
      # @param [Netomox::PseudoDSL::PTermPoint] l1_tp layer1 term-point under the new layer2 term-point
      # @param [InterfacePropertiesTableRecord] l1_tp_prop Layer1 (phy) or unit interface property
      # @param [Integer] vlan_id VLAN id (if used)
      # @return [String] Name of layer2 term-point
      def l2_tp_name(l1_node, l1_tp, l1_tp_prop, vlan_id)
        if owns_l3_sub_interface?(l1_node, l1_tp)
          found_rec = @intf_props.find_all_records_by_node(l1_node.name).find do |rec|
            rec.interface =~ /#{l1_tp.name}/ && rec.encapsulation_vlan == vlan_id
          end
          raise StandardError, "Subif not found of #{l1_node.name}[#{l1_tp.name}]" if found_rec.nil?

          found_rec.interface
        else
          l1_tp_prop.interface
        end
      end

      # @param [Netomox::PseudoDSL::PNode] l1_node layer1 node under l2_node
      # @param [Netomox::PseudoDSL::PTermPoint] l1_tp layer1 term-point under the new layer2 term-point
      # @param [InterfacePropertiesTableRecord] l1_tp_prop Layer1 (phy) interface property
      # return [Array<Array<String>>] Support node/tp data
      def l2_tp_supports(l1_node, l1_tp, l1_tp_prop)
        if l1_tp_prop.lag_parent?
          l1_tp_prop.lag_member_interfaces.map { |intf| [@layer1p.name, l1_node.name, intf] }
        else
          [[@layer1p.name, l1_node.name, l1_tp.name]]
        end
      end

      # @param [Netomox::PseudoDSL::PNode] l1_node layer1 node under l2_node
      # @param [Netomox::PseudoDSL::PTermPoint] l1_tp layer1 term-point under the new layer2 term-point
      # @param [InterfacePropertiesTableRecord] l1_tp_prop Layer1 (phy) or unit interface property
      def l2_tp_attribute(l1_node, l1_tp, l1_tp_prop)
        # for junos sub-interface: it assumes trunk, @see: L2DataChecker#change_property_as_trunk
        debug_print "  l2_tp_attr: #{l1_node.name}[#{l1_tp.name}], swp_mode: #{l1_tp_prop.switchport_mode}"
        swp_mode = l1_tp_prop.switchport_mode.downcase
        {
          description: l1_tp_prop.description,
          switchport_mode: swp_mode,
          encapsulation: swp_mode == 'trunk' ? l1_tp_prop.switchport_trunk_encapsulation.downcase : ''
        }
      end

      # @param [Netomox::PseudoDSL::PNode] l2_node Layer2 node to add new term-point
      # @param [Netomox::PseudoDSL::PNode] l1_node layer1 node under l2_node
      # @param [Netomox::PseudoDSL::PTermPoint] l1_tp layer1 term-point under the new layer2 term-point
      # @param [InterfacePropertiesTableRecord] l1_tp_prop Layer1 (phy) or unit interface property
      # @return [Netomox::PseudoDSL::PTermPoint] Added layer2 term-point
      # @raise [StandardError] if layer1 term-point property is not found
      def add_l2_tp(l2_node, l1_node, l1_tp, l1_tp_prop, vlan_id)
        new_tp = l2_node.term_point(l2_tp_name(l1_node, l1_tp, l1_tp_prop, vlan_id))
        l1_tp_prop = @intf_props.find_record_by_node_intf(l1_node.name, l1_tp.name)
        raise StandardError, "Layer1 term-point property not found: #{l1_node.name}[#{l1_tp.name}]" unless l1_tp_prop

        # same supports are added for LAG
        new_tp.supports.push(*l2_tp_supports(l1_node, l1_tp, l1_tp_prop)).uniq!
        new_tp.attribute = l2_tp_attribute(l1_node, l1_tp, l1_tp_prop)
        new_tp
      end

      # @param [Netomox::PseudoDSL::PNode] l1_node A node under the new layer2 node
      # @param [Netomox::PseudoDSL::PTermPoint] l1_tp Layer1 term-point under the new layer2 term-point
      # @param [InterfacePropertiesTableRecord] l1_tp_prop Layer1 (phy) or unit interface property
      # @param [Integer] vlan_id vlan_id VLAN id (if used)
      # @return [Array(Netomox::PseudoDSL::PNode, Netomox::PseudoDSL::PTermPoint)] A pair of added node name and tp name
      def add_l2_node_tp(l1_node, l1_tp, l1_tp_prop, vlan_id)
        new_node = add_l2_node(l1_node, l1_tp_prop, vlan_id)
        new_tp = add_l2_tp(new_node, l1_node, l1_tp, l1_tp_prop, vlan_id)
        [new_node, new_tp]
      end

      # rubocop:disable Metrics/ParameterLists

      # @param [Netomox::PseudoDSL::PNode] src_node L1 link source node
      # @param [Netomox::PseudoDSL::PTermPoint] src_tp L1 link source tp (on src_node)
      # @param [InterfacePropertiesTableRecord] src_tp_prop L1 term-point property of src_tp
      # @param [Integer] src_vlan_id VLAN id of src_tp
      # @param [Netomox::PseudoDSL::PNode] dst_node L1 link destination node
      # @param [Netomox::PseudoDSL::PTermPoint] dst_tp L1 link destination port (on dst_node)
      # @param [InterfacePropertiesTableRecord] dst_tp_prop L1 term-point property of dst_tp
      # @param [Integer] dst_vlan_id VLAN id of dst_tp
      # @return [void]
      def add_l2_node_tp_link(src_node, src_tp, src_tp_prop, src_vlan_id, dst_node, dst_tp, dst_tp_prop, dst_vlan_id)
        src_l2_node, src_l2_tp = add_l2_node_tp(src_node, src_tp, src_tp_prop, src_vlan_id).map(&:name)
        dst_l2_node, dst_l2_tp = add_l2_node_tp(dst_node, dst_tp, dst_tp_prop, dst_vlan_id).map(&:name)
        # NOTE: Layer2 link is added according to layer1 link.
        # Therefore, layer1 link is bidirectional, layer2 is same
        debug_print "  Add L2 link: #{src_l2_node}[#{src_l2_tp}] > #{dst_l2_node}[#{dst_l2_tp}]"
        @network.link(src_l2_node, src_l2_tp, dst_l2_node, dst_l2_tp)
      end
      # rubocop:enable Metrics/ParameterLists

      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize

      # @param [Netomox::PseudoDSL::PNode] src_node L1 link source node
      # @param [Netomox::PseudoDSL::PTermPoint] src_tp L1 link source tp (on src_node)
      # @param [Netomox::PseudoDSL::PNode] dst_node L1 link destination node
      # @param [Netomox::PseudoDSL::PTermPoint] dst_tp L1 link destination port (on dst_node)
      # @param [Hash] check_result L2 config check result (@see: port_l2_config_check)
      # @return [void]
      def add_l2_node_tp_link_by_config(src_node, src_tp, dst_node, dst_tp, check_result)
        case check_result[:type]
        when :access
          add_l2_node_tp_link(
            src_node, src_tp, check_result[:src_tp_prop], check_result[:src_vlan_id],
            dst_node, dst_tp, check_result[:dst_tp_prop], check_result[:dst_vlan_id]
          )
        when :trunk
          check_result[:vlan_ids].each do |vlan_id|
            add_l2_node_tp_link(src_node, src_tp, check_result[:src_tp_prop], vlan_id,
                                dst_node, dst_tp, check_result[:dst_tp_prop], vlan_id)
          end
        else
          # type: :error
          add_l2_node_tp(src_node, src_tp, check_result[:src_tp_prop], 0)
          add_l2_node_tp(dst_node, dst_tp, check_result[:dst_tp_prop], 0)
          @logger.error "L2 term-point check error: #{check_result[:message]}"
        end
      end
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

      # @param [String] lag_tp_name Layer1 LAG (parent) term-point name
      # @param [Netomox::PseudoDSL::PTermPoint] member_tp Layer1 LAG member term-point name
      # @return [Netomox::PseudoDSL::PTermPoint] LAG (parent) term-point
      def make_l1_lag_tp(lag_tp_name, member_tp)
        l1_lag_tp = Netomox::PseudoDSL::PTermPoint.new(lag_tp_name)
        l1_lag_tp.attribute = member_tp.attribute
        l1_lag_tp.supports = member_tp.supports
        l1_lag_tp
      end

      # @param [Netomox::PseudoDSL::PLinkEdge] link_edge A Link-edge to get interface property
      # @return [Array(Netomox::PseudoDSL::PNode, Netomox::PseudoDSL::PTermPoint, InterfacePropertiesTableRecord)]
      # @raise [StandardError] if term-point props of the link-edge is not found
      def l1_link_edge_to_node_tp(link_edge)
        node = @layer1p.find_node_by_name(link_edge.node)
        tp = node.find_tp_by_name(link_edge.tp)
        tp_prop = @intf_props.find_record_by_node_intf(node.name, tp.name)
        raise StandardError, "Term point not found: #{link_edge}" unless tp_prop

        [node, tp, tp_prop]
      end

      # @param [Netomox::PseudoDSL::PLinkEdge] link_edge A Link-edge to get interface property
      # @return [Array(Netomox::PseudoDSL::PNode, Netomox::PseudoDSL::PTermPoint, InterfacePropertiesTableRecord)]
      #   Node, interface, interface property of the edge
      def tp_prop_by_link_edge(link_edge)
        node, tp, tp_prop = l1_link_edge_to_node_tp(link_edge)
        [
          node,
          tp_prop.lag_member? ? make_l1_lag_tp(tp_prop.lag_parent_interface, tp) : tp,
          tp_prop.lag_member? ? @intf_props.find_record_by_node_intf(node.name, tp_prop.lag_parent_interface) : tp_prop
        ]
      end

      # @param [Netomox::PseudoDSL::PLinkEdge] link_edge
      # @return [Array(Netomox::PseudoDSL::PNode, Netomox::PseudoDSL::PTermPoint)]
      def l2_link_edge_to_node_tp(link_edge)
        node = @network.find_node_by_name(link_edge.node)
        tp = node.find_tp_by_name(link_edge.tp)
        [node, tp]
      end

      # @param [Netomox::PseudoDSL::PNode] l2_tp
      # @return [Array(Netomox::PseudoDSL::PNode, Netomox::PseudoDSL::PTermPoint)]
      #   layer1 node, term-point under l2_node/l2_tp
      def l1_supported_node_tp_list(l2_tp)
        # NOTE: usually, l2_node and l2_tp (in l2_node) has same support path (network__node)
        l2_tp_l1sups = l2_tp.supports.find_all { |s| s[0] == @layer1p.name }
        sups = l2_tp_l1sups.map do |l2_tp_l1sup|
          l1_node, l1_tp = @layer1p.find_node_tp_by_name(l2_tp_l1sup[1], l2_tp_l1sup[2])
          [l1_node, l1_tp]
        end
        # NOTE: for link-down test: There is a case that supported interface is not found in intf-props table
        sups.reject { |s| s[1].nil? }
      end

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength

      # @return [Array<Hash>]
      def enumerate_connected_intfs
        connected_intfs = []
        @network.links.each do |l2_link|
          l2_node, l2_tp = l2_link_edge_to_node_tp(l2_link.src)
          debug_print "* l2: #{l2_node.name}[#{l2_tp.name}], tp_sups=#{l2_tp.supports}"
          l1_sups = l1_supported_node_tp_list(l2_tp)
          l1_sups.each do |l1_sup|
            l1_node, l1_tp = l1_sup
            debug_print "  l1: #{l1_node.name}[#{l1_tp.name}]"

            # logical (Cisco SVI) interface name
            if l1_node.attribute[:os_type] =~ /(cisco|arista)/i && l2_node.name =~ /.+_Vlan(\d+)/
              connected_intfs.push({ node: l1_node.name, intf: "Vlan#{Regexp.last_match[1]}" })
            end
            # logical (unit/LAG) interface name
            tp_sup = @intf_props.find_record_by_node_intf(l1_node.name, l2_tp.name)
            connected_intfs.push({ node: tp_sup.node, intf: tp_sup.interface })
            # physical interface name
            connected_intfs.push({ node: l1_node.name, intf: l1_tp.name })
          end
        end
        connected_intfs.uniq
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      # @param [Array<Hash>] whole_intfs
      # @param [Array<Hash>] connected_intfs
      # @return [Array<Hash>] disconnected_interfaces
      def filtered_disconnected_intfs(whole_intfs, connected_intfs)
        disconnected_intfs = whole_intfs - connected_intfs
        # reject layer2 ports
        disconnected_intfs.reject do |intf|
          prop = @intf_props.find_record_by_node_intf(intf[:node], intf[:intf])
          return false unless prop # keep it as disconnected one

          prop.primary_address.nil? or prop.primary_address.empty?
        end
      end

      # @return [void]
      def check_disconnected_node
        debug_print '# check disconnected node'
        connected_intfs = enumerate_connected_intfs
        debug_print("# connected_intfs = #{connected_intfs}")
        whole_intfs = @intf_props.records.map { |rec| { node: rec.node, intf: rec.interface } }
        debug_print "# whole_interfaces = #{whole_intfs}"
        disconnected_intfs = filtered_disconnected_intfs(whole_intfs, connected_intfs)
        debug_print "# disconnected_interfaces (rej) = #{disconnected_intfs}"
        disconnected_intfs.each do |intf|
          @logger.warn "L3 interface #{intf[:node]}[#{intf[:intf]}] is inactive or disconnected (L1/L2)."
        end
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

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength

      # add unlinked interface which owns ip address (interface to external network/AS)
      # @return [void]
      def add_unlinked_ip_owner_tp
        debug_print '# add_unlinked_tp'
        @layer1p.nodes.each do |l1_node|
          debug_print "  - target node: #{l1_node.name}"
          l1_node.tps.each do |l1_tp|
            l1_link = @layer1p.find_link_by_src_name(l1_node.name, l1_tp.name)
            next if l1_link

            debug_print "    - find unlinked L1 tp: #{l1_tp.name}"
            link_edge = Netomox::PseudoDSL::PLinkEdge.new(l1_node.name, l1_tp.name)
            _, _, tp_prop = tp_prop_by_link_edge(link_edge)
            tp_prop = choose_tp_prop(l1_node, tp_prop)
            debug_print "    - tp prop: #{tp_prop}"

            # unlinked interface is L3 (routed)
            # @see [L1DataBuilder#add_unlinked_ip_owner_tp]
            add_l2_node_tp(l1_node, l1_tp, tp_prop, 0)
          end
        end
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
    end
    # rubocop:enable Metrics/ClassLength
  end
end
