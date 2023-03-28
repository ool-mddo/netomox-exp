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
    # @return [String]
    # @raise [StandardError]
    def convert(src_node_name, src_tp_name)
      raise StandardError, "Node: #{src_node_name} is not in tp-table" unless key_in_table?(src_node_name)
      raise StandardError, "TP: #{src_tp_name} is not in tp-table" unless key_in_table?(src_node_name,
                                                                                        src_tp_name)

      @convert_table[src_node_name][src_tp_name]
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
    # @param [String] dst_tp_name Destination (converted) term-point name
    # @return [void]
    def add_tp_name_entry(src_node_name, src_tp_name, dst_node_name, dst_tp_name)
      # forward
      @convert_table[src_node_name][src_tp_name] = dst_tp_name unless key_in_table?(src_node_name, src_tp_name)
      # reverse
      @convert_table[dst_node_name][dst_tp_name] = src_tp_name unless key_in_table?(dst_node_name, dst_tp_name)
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
        dst_node_name = @node_name_table.convert(src_node.name)
        add_tp_name_hash(src_node.name, dst_node_name)

        src_node.termination_points.find_all { |src_tp| loopback?(src_tp) }.each_with_index do |src_tp, index|
          # to cRPD: lo.X
          dst_tp_name = "lo.#{index}"
          add_tp_name_entry(src_node.name, src_tp.name, dst_node_name, dst_tp_name)
        end
        src_node.termination_points.reject { |src_tp| loopback?(src_tp) }.each_with_index do |src_tp, index|
          dst_tp_name = forward_convert_actual_tp_name(src_node, index + 1)
          add_tp_name_entry(src_node.name, src_tp.name, dst_node_name, dst_tp_name)
        end
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    # @param [Netomox::Topology::Network] src_nw Source network (L3)
    def make_table_for_segment(src_nw)
      src_nw.nodes.select { |node| segment_node?(node) }.each do |src_node|
        dst_node_name = @node_name_table.convert(src_node.name)
        add_tp_name_hash(src_node.name, dst_node_name)
        src_node.termination_points.each do |src_tp|
          dst_tp_name = forward_convert_segment_tp_name(src_nw, src_node, src_tp)
          add_tp_name_entry(src_node.name, src_tp.name, dst_node_name, dst_tp_name)
        end
      end
    end

    # @param [Netomox::Topology::Node] src_node Source node (L3)
    # @param [Integer] index Term-point index
    # @return [String] Converted term-point name
    def forward_convert_actual_tp_name(src_node, index)
      # for actual node (some container in emulated env)
      "eth#{index}.0" unless segment_node?(src_node)
    end

    # @param [Netomox::Topology::Network] src_nw Source network (L3)
    # @param [Netomox::Topology::Node] src_node Source node (L3)
    # @param [Netomox::Topology::TermPoint] src_tp Source term-point (L3)
    # @return [String] Converted term-point name
    # @raise [StandardError] if link connected src_node/tp is not found
    def forward_convert_segment_tp_name(src_nw, src_node, src_tp)
      link = src_nw.find_link_by_source(src_node.name, src_tp.name)
      raise StandardError, "Link is not found source: #{src_tp.path}" if link.nil?

      target_node_ref = link.destination.node_ref
      target_tp_ref = link.destination.tp_ref
      "#{@node_name_table.convert(target_node_ref)}_#{convert(target_node_ref, target_tp_ref)}"
    end
  end
end
