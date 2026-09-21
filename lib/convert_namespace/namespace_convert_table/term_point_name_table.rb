# frozen_string_literal: true

require_relative 'convert_table_base'

module NetomoxExp
  # rubocop:disable-next Metrics/ClassLength
  module ConvertNamespace
    # Term-point name convert table
    class TermPointNameTable < ConvertTableBase
      # @param [NodeNameTable] node_name_table
      def initialize(node_name_table)
        super()
        @node_name_table = node_name_table
        @usecase_params = {}
      end

      # @param [String] src_node_name Source node name
      # @param [String] src_tp_name Source term-point name
      # @return [Hash] term-point name dic
      # @raise [StandardError]
      def convert(src_node_name, src_tp_name)
        raise StandardError, "Node: #{src_node_name} is not in tp-table" unless key?(src_node_name)
        raise StandardError, "TP: #{src_tp_name} is not in tp-table" unless key?(src_node_name, src_tp_name)

        # key string is "L3 model name"
        #
        # # forward convert
        # original_node_name => {
        #   original_tp_name => {                            # <= converted name dictionary
        #     'l3_model' => 'emulated_tp_name (L3 model)',
        #     'l1_agent' => 'emulated_tp_name (emulated env L1 config, cEOS for segment-node)',
        #     'l1_principal' => 'emulated_tp_name (emulated env instance, OVS for segment-node)'
        #   }
        # },
        # # backward convert
        # emulated_node_name => {
        #   emulated_tp_name => {
        #     'l3_model' => 'original_tp_name (L3 model)',
        #     'l1_agent' => 'original_tp_name (L3 model)',
        #     'l1_principal' => 'original_tp_name (L3 model)'
        #   }
        # }
        # NOTE: all keys must be String, because string node name is used as dictionary key.
        #   if reload the table from file, ALL keys will be string or symbol...
        @convert_table[src_node_name][src_tp_name]
      end

      # @param [String] l3_node_name Node name (L3) (original/emulated)
      # @param [String] l3_tp_name Node name (L3) (original/emulated)
      # @return [Array(String, String)] List [node-name, tp-name] (emulated/original)
      def reverse_lookup(l3_node_name, l3_tp_name)
        rev_node = @node_name_table.reverse_lookup(l3_node_name)
        rev_tp = @convert_table[rev_node].keys.find { |tp| @convert_table[rev_node][tp]['l3_model'] == l3_tp_name }
        [rev_node, rev_tp]
      end

      # @param [String] l3_node_name Node name (L3)
      # @param [String] l3_tp_name Term-point name (L3)
      # @return [nil,Hash] Term-point name dic
      def find_l1_alias(l3_node_name, l3_tp_name)
        orig_node, orig_tp = reverse_lookup(l3_node_name, l3_tp_name)
        @convert_table[orig_node][orig_tp]
      end

      # @param [String] node_name Node name
      # @param [String] tp_name Term-point name
      # @return [Boolean] True if the node and term-point are in term-point table key
      def key?(node_name, tp_name = nil)
        return @convert_table.key?(node_name) if tp_name.nil?

        @convert_table.key?(node_name) && @convert_table[node_name].key?(tp_name)
      end

      # @param [Netomox::Topology::Network] src_nw Source network (layer3)
      # @return [void]
      # @raise [StandardError] if target layer is not found
      def make_layer3_tp_table(src_nw)
        raise StandardError, 'Network: layer3 is not found' if src_nw.nil?

        make_table_for_actual(src_nw)
        make_table_for_firewall_actual(src_nw)
        # NOTE: The node name and interface name of the node facing it
        #   are used for the interface name of the segment node.
        #   Therefore, it is necessary to first create an interface name conversion table for the node.
        make_table_for_segment(src_nw)
      end

      # rubocop:disable Metrics/AbcSize

      # @param [Netomox::Topology::Network] src_nw Source network (bgp-proc/as)
      # @return [void]
      # @raise [StandardError] if target layer is not found
      def make_pass_through_tp_table(src_nw)
        # nothing to do if target layer is not found
        return if src_nw.nil?

        src_nw.nodes.each do |node|
          node.termination_points.each do |tp|
            # node name is not converted in node table
            @convert_table[node.name] = {} unless key?(node.name)
            @convert_table[node.name][tp.name] = pass_through_name_dict(tp.name) unless key?(node.name, tp.name)
          end
        end
      end
      # rubocop:enable Metrics/AbcSize

      # @param [Netomox::Topology::Networks] src_nws Source networks
      # @param [Hash] usecase_params Usecase parameters (optional)
      # @return [void]
      def make_table(src_nws, usecase_params = {})
        super(src_nws)

        # usecase params
        @usecase_params = usecase_params

        # convert table (for layer3, ospf-area)
        make_layer3_tp_table(@src_nws.find_network('layer3'))

        # convert table (not converted: for bgp-proc, bgp-as)
        %w[bgp_proc bgp_as].each do |nw_name|
          make_pass_through_tp_table(@src_nws.find_network(nw_name))
        end
      end

      private

      # @param [String] src_node_name Source (original) node name
      # @param [String] src_tp_name Source (original) term-point name
      # @param [String] dst_node_name Destination (converted) node name
      # @param [Hash] dst_tp_dic Destination (converted) term-point name dictionary
      # @return [void]
      def add_tp_name_entry(src_node_name, src_tp_name, dst_node_name, dst_tp_dic)
        # forward
        @convert_table[src_node_name][src_tp_name] = dst_tp_dic unless key?(src_node_name, src_tp_name)
        # reverse
        return if key?(dst_node_name, dst_tp_dic['l3_model'])

        @convert_table[dst_node_name][dst_tp_dic['l3_model']] = emulated_name_dict(src_tp_name)
      end

      # @param [String] src_node_name Source (original) node name
      # @param [String] dst_node_name Destination (converted) node name
      # @return [void]
      def add_tp_name_hash(src_node_name, dst_node_name)
        # forward
        @convert_table[src_node_name] = {} unless key?(src_node_name)
        # reverse
        @convert_table[dst_node_name] = {} unless key?(dst_node_name)
      end

      # @param [Netomox::Topology::Node] src_node Source node
      # @param [Netomox::Topology::TermPoint] src_tp Source term-point
      # @return [Boolean] True if the term-point is specified in usecase_params
      def usecase_specified_tp?(src_node, src_tp)
        l3pr_key = 'l3_preallocated_resources'
        l3prs = @usecase_params[l3pr_key]

        return false unless l3prs&.any?

        # find a node from usecase params (l3_preallocated_resources)
        # if exist a node that has `emulated_params` key, it is "specified" in usecase_params
        l3prs.any? do |l3pr|
          next false unless l3pr['type'] == 'node'
          next false unless l3pr['name'] == src_node.name
          next false unless l3pr['interfaces'].include?(src_tp.name)

          l3pr.key?('emulated_params')
        end
      end

      # @param [Netomox::Topology::Node] src_node Source node
      # @param [Netomox::Topology::TermPoint] src_tp Source term-point
      # @param [Integer] index Term-point index
      # @return [Hash] Converted term-point name dic
      def select_actual_tp_dic(src_node, src_tp, index)
        if usecase_specified_tp?(src_node, src_tp)
          forward_convert_pass_through_tp_name(src_tp.name)
        else
          forward_convert_actual_tp_name(index + 1)
        end
      end

      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength

      # @param [Netomox::Topology::Network] src_nw Source network (L3)
      # return [void]
      def make_table_for_actual(src_nw)
        src_nw.nodes.reject { |node| segment_node?(node) || firewall_node?(node) }.each do |src_node|
          dst_node_name = @node_name_table.convert(src_node.name)['l3_model']
          add_tp_name_hash(src_node.name, dst_node_name)

          src_node.termination_points.find_all { |src_tp| loopback?(src_tp) }.each do |src_tp|
            dst_tp_dic = forward_convert_actual_lo_name(src_tp.name)
            add_tp_name_entry(src_node.name, src_tp.name, dst_node_name, dst_tp_dic)
          end
          src_node.termination_points.reject { |src_tp| loopback?(src_tp) }.each_with_index do |src_tp, index|
            dst_tp_dic = select_actual_tp_dic(src_node, src_tp, index)
            add_tp_name_entry(src_node.name, src_tp.name, dst_node_name, dst_tp_dic)
          end
        end
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength

      # @param [Netomox::Topology::Network] src_nw Source network (L3)
      def make_table_for_segment(src_nw)
        src_nw.nodes.select { |node| segment_node?(node) }.each do |src_node|
          dst_node_name = @node_name_table.convert(src_node.name)['l3_model']
          add_tp_name_hash(src_node.name, dst_node_name)
          src_node.termination_points.each_with_index do |src_tp, tp_index|
            dst_tp_dic = forward_convert_segment_tp_name(src_nw, src_node, src_tp, tp_index)
            add_tp_name_entry(src_node.name, src_tp.name, dst_node_name, dst_tp_dic)
          end
        end
      end

      # @param [String] src_tp_name Source term-point name (pass-through)
      # @return [Hash] Converted term-point name
      def forward_convert_pass_through_tp_name(src_tp_name)
        emulated_name_dict(src_tp_name)
      end

      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

      # @param [Netomox::Topology::Network] src_nw Source network (L3)
      # @return [void]
      def make_table_for_firewall_actual(src_nw)
        src_nw.nodes.select { |node| firewall_node?(node) }.each do |src_node|
          dst_node_name = @node_name_table.convert(src_node.name)['l3_model']
          add_tp_name_hash(src_node.name, dst_node_name)

          src_node.termination_points.select { |src_tp| loopback?(src_tp) }.each do |src_tp|
            dst_tp_dic = forward_convert_actual_lo_name(src_tp.name)
            add_tp_name_entry(src_node.name, src_tp.name, dst_node_name, dst_tp_dic)
          end

          non_lo_tps = src_node.termination_points.reject { |src_tp| loopback?(src_tp) }
          eth_map = build_firewall_eth_map(non_lo_tps)
          non_lo_tps.each do |src_tp|
            dst_tp_dic = if usecase_specified_tp?(src_node, src_tp)
                           forward_convert_pass_through_tp_name(src_tp.name)
                         else
                           forward_convert_firewall_tp_name(src_tp.name, eth_map[src_tp.name])
                         end
            add_tp_name_entry(src_node.name, src_tp.name, dst_node_name, dst_tp_dic)
          end

          extract_fabric_member_interfaces(src_node).each do |iface|
            dst_tp_dic = forward_convert_firewall_tp_name(iface, 'eth3')
            add_tp_name_entry(src_node.name, iface, dst_node_name, dst_tp_dic)
          end
        end
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

      # @param [Array<Netomox::Topology::TermPoint>] non_lo_tps Non-loopback term-points of a firewall node
      # @return [Hash{String => String}] mapping: original tp name => l1_principal eth name
      def build_firewall_eth_map(non_lo_tps)
        phys = ->(tp) { tp.name.sub(/\.\d+$/, '') }

        management_tps = non_lo_tps.select { |tp| phys.call(tp) == 'management' }
        control_tps    = non_lo_tps.select { |tp| phys.call(tp) == 'control' }
        data_tps       = non_lo_tps.reject { |tp| %w[management control].include?(phys.call(tp)) }

        data_phys_sorted = data_tps.map { |tp| phys.call(tp) }.uniq
                                   .sort_by { |name| interface_sort_key(name) }

        result = {}
        management_tps.each { |tp| result[tp.name] = 'eth1' }
        control_tps.each    { |tp| result[tp.name] = 'eth2' }
        data_tps.each do |tp|
          idx = data_phys_sorted.index(phys.call(tp))
          result[tp.name] = "eth#{idx + 4}"
        end
        result
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

      # @param [Netomox::Topology::Node] node FW node
      # @return [Array<String>] physical interface names used as fabric members (e.g. ["ge-0/0/0"])
      def extract_fabric_member_interfaces(node)
        pair = node.attribute.firewall.pair
        node_side = [pair['primary'], pair['secondary']].find { |s| s && s['name'] == node.name }
        return [] if node_side.nil?

        node_side.fetch('atypical_interfaces', [])
                 .select { |i| i['role'] == 'fabric' }
                 .flat_map { |i| i.dig('fabric_options', 'member_interfaces') || [] }
      end

      # @param [String] iface_name Physical interface name (e.g. "ge-0/0/1")
      # @return [Array<Integer>] sort key
      def interface_sort_key(iface_name)
        m = iface_name.match(%r{[a-z]+-(\d+)/(\d+)/(\d+)})
        m ? m[1..3].map(&:to_i) : [999, 999, 999]
      end

      # @param [String] src_tp_name Source term-point name (firewall/vSRX interface)
      # @param [String] eth_name l1_principal name on the Proxmox host (e.g. "eth3")
      # @return [Hash] Converted term-point name dic
      def forward_convert_firewall_tp_name(src_tp_name, eth_name)
        # vSRX: l3_model and l1_agent keep the original JunOS interface name;
        # only l1_principal (Proxmox host side) maps to eth<N>.
        phys = src_tp_name.sub(/\.\d+$/, '')
        emulated_name_dict(src_tp_name, l1_agent: phys, l1_principal: eth_name)
      end

      # @param [String] src_tp_name Source term-point name (loopback)
      # @return [Hash] Converted term-point (loopback) name
      def forward_convert_actual_lo_name(src_tp_name)
        # pick last number e.g. loX.Y -> Y
        index = src_tp_name.match(/(\d+)$/)[-1]
        emulated_name_dict("lo0.#{index}") # cRPD loopback
      end

      # @param [Integer] index Term-point index
      # @return [Hash] Converted term-point name dic
      def forward_convert_actual_tp_name(index)
        # for actual node (some container in emulated env)
        # NOTE: l1_agent for cRPD, use physical interface name (without unit number),
        #   When converting original topology to emulated topology,
        #   it assumes L3 topology of original as L1 topology of emulated.
        #   l1_agent is "name in device configuration" in emulated.
        #   Therefore, use physical name of a interface on cRPD as l1_agent name
        emulated_name_dict("eth#{index}.0", l1_agent: "eth#{index}", l1_principal: "eth#{index}") # cRPD interface
      end

      # rubocop:disable Metrics/AbcSize

      # @param [Netomox::Topology::Network] src_nw Source network (L3)
      # @param [Netomox::Topology::Node] src_node Source node (L3)
      # @param [Netomox::Topology::TermPoint] src_tp Source term-point (L3)
      # @param [Integer] tp_index Term-point index (start:0)
      # @return [Hash] Converted term-point name dic
      # @raise [StandardError] if link connected src_node/tp is not found
      def forward_convert_segment_tp_name(src_nw, src_node, src_tp, tp_index)
        link = src_nw.find_link_by_source(src_node.name, src_tp.name)
        raise StandardError, "Link is not found source: #{src_tp.path}" if link.nil?

        target_node_ref = link.destination.node_ref
        target_tp_ref = link.destination.tp_ref
        target_node_dic = @node_name_table.convert(target_node_ref)
        src_node_dic = @node_name_table.convert(src_node.name)

        l3_model = "#{target_node_dic['l3_model']}_#{convert(target_node_ref, target_tp_ref)['l3_model']}"
        l1_agent = "Ethernet#{tp_index + 1}" # cEOS interface
        l1_principal = "#{src_node_dic['l1_principal']}p#{tp_index}"
        emulated_name_dict(l3_model, l1_agent:, l1_principal:)
      end
      # rubocop:enable Metrics/AbcSize
    end
  end
end
