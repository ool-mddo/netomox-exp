# frozen_string_literal: true

require_relative 'l1_data_builder'
require_relative 'csv_mapper/ip_owners_table'

module NetomoxExp
  module TopologyBuilder
    # Extended L1 data builder
    #   Add unlinked but ip-owner interfaces ()term-points) into Layer1.
    class L1L3DataBuilder < L1DataBuilder
      # @param [String] target Target network (config) data name
      def initialize(target:, debug: false)
        super(target:, debug:)

        @ip_owners = CSVMapper::IPOwnersTable.new(target)
      end

      # @return [Netomox::PseudoDSL::PNetworks] Networks contains only layer1 network topology
      def make_networks
        super()

        add_unlinked_ip_owner_tp
        @networks
      end

      private

      # @param [Netomox::PseudoDSL::PNode] l1_node Layer1 node
      # @return [Boolean] True if the node os-type is juniper
      def juniper_node?(l1_node)
        l1_node.attribute[:os_type].downcase == 'juniper'
      end

      # @param [Netomox::PseudoDSL::PNode] l1_node Layer1 node
      # @param [CSVMapper::IPOwnersTableRecord] rec A record of ip_owners table
      # @return [String] physical interface name for junos (nothing to do for other OS)
      def select_physical_tp_name(l1_node, rec)
        # e.g. xe-0/3/0:0.0, ge-0/0/1.0
        juniper_node?(l1_node) ? rec.interface.gsub(/(\d+(?::\d+)?)\.\d+/, '\1') : rec.interface
      end

      # @param [Netomox::PseudoDSL::PNode] l1_node Layer1 node
      # @param [NetomoxExp::CSVMapper::IPOwnersTableRecord] rec A record of ip-owner table
      # @return [Array<String>] Member interface names
      def find_all_lag_member_interfaces(l1_node, rec)
        # if ip-owner interface is junos unit interface, convert to physical interface name
        l1_tp_name = select_physical_tp_name(l1_node, rec)
        intf_prop_rec = @intf_props.find_record_by_node_intf(l1_node.name, l1_tp_name)

        # not found
        if intf_prop_rec.nil?
          @logger.error("#{l1_node.name}[#{l1_tp_name}] is not found in interface-prop table")
          return []
        end

        # return itself as member-interface to add Layer1 if the interface is not LAG
        return [l1_tp_name] unless intf_prop_rec.lag_parent?

        intf_prop_rec.lag_member_interfaces
      end

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength

      # add unlinked interface which owns ip address (interface to external network/AS)
      # @return [void]
      def add_unlinked_ip_owner_tp
        debug_print '# add_unlinked_ip_owner_tp'
        @network.nodes.each do |l1_node|
          debug_print "  - target node: #{l1_node.name}"
          @ip_owners.find_all_records_by_node(l1_node.name).each do |rec|
            l1_link = @network.find_link_by_src_name(l1_node.name, rec.interface)
            # nothing to do if the term-point is linked (L1) or logical interface
            next if l1_link || rec.loopback_interface?

            debug_print "    - find unlinked tp: #{rec.interface}"
            # if aggregated interface (LAG), add its children
            find_all_lag_member_interfaces(l1_node, rec).each do |member_tp_name|
              debug_print "    - add unlinked tp: #{rec.interface}"
              add_node_tp(l1_node.name, member_tp_name)
            end
          end
        end
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
    end
  end
end
