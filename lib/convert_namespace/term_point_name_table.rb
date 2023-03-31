# frozen_string_literal: true

require_relative 'convert_table_base'

module NetomoxExp
  # Term-point name convert table
  class TermPointNameTable < ConvertTableBase
    # @param [NodeNameTable] node_name_table
    def initialize(node_name_table)
      super()
      @node_name_table = node_name_table
    end

    # @param [String] src_node_name Source node name
    # @param [String] src_tp_name Source term-point name
    # @return [Hash] term-point name dic
    # @raise [StandardError]
    def convert(src_node_name, src_tp_name)
      raise StandardError, "Node: #{src_node_name} is not in tp-table" unless key_in_table?(src_node_name)
      raise StandardError, "TP: #{src_tp_name} is not in tp-table" unless key_in_table?(src_node_name,
                                                                                        src_tp_name)

      # # forward convert
      # original_node_name => {
      #   original_tp_name => {                            # <= converted name dictionary
      #     'l3' => 'emulated_tp_name (L3 model)',
      #     'l1_agent' => 'emulated_tp_name (emulated env L1 config, cEOS for segment-node)',
      #     'l1_principal' => 'emulated_tp_name (emulated env instance, OVS for segment-node)'
      #   }
      # },
      # # backward convert
      # emulated_node_name => {
      #   emulated_tp_name => {
      #     'l3' => 'original_tp_name (L3 model)',
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
      rev_tp = @convert_table[rev_node].keys.find { |tp| @convert_table[rev_node][tp]['l3'] == l3_tp_name }
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
    def key_in_table?(node_name, tp_name = nil)
      return @convert_table.key?(node_name) if tp_name.nil?

      @convert_table.key?(node_name) && @convert_table[node_name].key?(tp_name)
    end

    # @param [Netomox::Topology::Networks] src_nws Source networks
    # @return [void]
    # @raise [StandardError] if target layer (layer3) is not found
    def make_table(src_nws)
      super(src_nws)
      src_nw = @src_nws.find_network('layer3')
      raise StandardError, 'Network: layer3 is not found' if src_nw.nil?

      make_table_for_actual(src_nw)
      # NOTE: The node name and interface name of the node facing it
      #   are used for the interface name of the segment node.
      #   Therefore, it is necessary to first create an interface name conversion table for the node.
      make_table_for_segment(src_nw)
    end

    private

    # @param [String] src_node_name Source (original) node name
    # @param [String] src_tp_name Source (original) term-point name
    # @param [String] dst_node_name Destination (converted) node name
    # @param [Hash] dst_tp_dic Destination (converted) term-point name dictionary
    # @return [void]
    def add_tp_name_entry(src_node_name, src_tp_name, dst_node_name, dst_tp_dic)
      # forward
      @convert_table[src_node_name][src_tp_name] = dst_tp_dic unless key_in_table?(src_node_name, src_tp_name)
      # reverse
      return if key_in_table?(dst_node_name, dst_tp_dic['l3'])

      @convert_table[dst_node_name][dst_tp_dic['l3']] = emulated_name_dict_short(src_tp_name)
    end

    # @param [String] src_node_name Source (original) node name
    # @param [String] dst_node_name Destination (converted) node name
    # @return [void]
    def add_tp_name_hash(src_node_name, dst_node_name)
      # forward
      @convert_table[src_node_name] = {} unless key_in_table?(src_node_name)
      # reverse
      @convert_table[dst_node_name] = {} unless key_in_table?(dst_node_name)
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength

    # @param [Netomox::Topology::Network] src_nw Source network (L3)
    def make_table_for_actual(src_nw)
      src_nw.nodes.reject { |node| segment_node?(node) }.each do |src_node|
        dst_node_name = @node_name_table.convert(src_node.name)['l3']
        add_tp_name_hash(src_node.name, dst_node_name)

        src_node.termination_points.find_all { |src_tp| loopback?(src_tp) }.each do |src_tp|
          dst_tp_dic = forward_convert_actual_lo_name(src_tp.name)
          add_tp_name_entry(src_node.name, src_tp.name, dst_node_name, dst_tp_dic)
        end
        src_node.termination_points.reject { |src_tp| loopback?(src_tp) }.each_with_index do |src_tp, index|
          dst_tp_dic = forward_convert_actual_tp_name(index + 1)
          add_tp_name_entry(src_node.name, src_tp.name, dst_node_name, dst_tp_dic)
        end
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    # @param [Netomox::Topology::Network] src_nw Source network (L3)
    def make_table_for_segment(src_nw)
      src_nw.nodes.select { |node| segment_node?(node) }.each do |src_node|
        dst_node_name = @node_name_table.convert(src_node.name)['l3']
        add_tp_name_hash(src_node.name, dst_node_name)
        src_node.termination_points.each_with_index do |src_tp, tp_index|
          dst_tp_dic = forward_convert_segment_tp_name(src_nw, src_node, src_tp, tp_index)
          add_tp_name_entry(src_node.name, src_tp.name, dst_node_name, dst_tp_dic)
        end
      end
    end

    # @param [String] src_tp_name Source term-point name (loopback)
    # @return [Hash] Converted term-point (loopback) name
    def forward_convert_actual_lo_name(src_tp_name)
      # pick last number e.g. loX.Y -> Y
      index = src_tp_name.match(/(\d+)/)[-1]
      emulated_name_dict_short("lo.#{index}") # cRPD loopback
    end

    # @param [Integer] index Term-point index
    # @return [Hash] Converted term-point name dic
    def forward_convert_actual_tp_name(index)
      # for actual node (some container in emulated env)
      emulated_name_dict_short("eth#{index}.0")
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength

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
      emulated_name_dict(
        "#{target_node_dic['l3']}_#{convert(target_node_ref, target_tp_ref)['l3']}",
        "Ethernet#{tp_index + 1}",
        "#{src_node_dic['l1_principal']}p#{tp_index}"
      )
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
  end
end
