# frozen_string_literal: true

require 'json'
require 'netomox'

module TopologyOperator
  # convert table
  class NamespaceConvertTable
    # @param [String] file Topology file path
    def initialize(file)
      @src_nws = read_networks(file)
      @node_name_table = {}
      @tp_name_table = {}
    end

    # @param [String] src_node_name Source node name
    # @return [String]
    # @raise [StandardError]
    def convert_node_name(src_node_name)
      raise StandardError, "Node name: #{src_node_name} is not in node-table" unless key_node?(src_node_name)

      @node_name_table[src_node_name]
    end

    # @param [String] src_node_name Source node name
    # @param [String] src_tp_name Source term-point name
    # @return [String]
    # @raise [StandardError]
    def convert_tp_name(src_node_name, src_tp_name)
      raise StandardError, "Node: #{src_node_name} is not in tp-table" unless key_node_tp?(src_node_name)
      raise StandardError, "TP: #{src_tp_name} is not in tp-table" unless key_node_tp?(src_node_name, src_tp_name)

      @tp_name_table[src_node_name][src_tp_name]
    end

    # @param [String] node_name Node name
    # @return [Boolean] True if the node name is in node table key
    def key_node?(node_name)
      @node_name_table.key?(node_name)
    end

    # @param [String] node_name Node name
    # @param [String] tp_name Term-point name
    # @return [Boolean] True if the node and term-point are in term-point table key
    def key_node_tp?(node_name, tp_name = nil)
      return @tp_name_table.key?(node_name) if tp_name.nil?

      @tp_name_table.key?(node_name) && @tp_name_table[node_name].key?(tp_name)
    end

    # @return [Hash]
    def convert_table
      { 'node_name_table' => @node_name_table, 'tp_name_table' => @tp_name_table }
    end

    # @return [void]
    def make_convert_table
      make_node_name_table
      make_tp_name_table
    end

    # @param [String] file Path of convert table file (json)
    # @return [void]
    def reload_convert_table(file)
      table_data = JSON.parse(File.read(file))
      @node_name_table = table_data['node_name_table']
      @tp_name_table = table_data['tp_name_table']
    end

    private

    # @param [Netomox::Topology::Node] src_node Source node (L3)
    # @param [Integer] index Term-point index
    # @return [String] Converted term-point name
    def forward_convert_tp_name(src_node, index)
      return "#{src_node.name.tr('_/', '-').downcase}_Ethernet#{index}" if src_node.attribute.node_type == 'segment'

      "eth#{index}.0"
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength

    # @return [void]
    def make_tp_name_table
      src_nw = @src_nws.find_network('layer3')
      src_nw.nodes.each do |src_node|
        dst_node_name = convert_node_name(src_node.name)

        # forward
        @tp_name_table[src_node.name] = {} unless key_node_tp?(src_node.name)
        # reverse
        @tp_name_table[dst_node_name] = {} unless key_node_tp?(dst_node_name)

        src_node.termination_points.each_with_index do |src_tp, index|
          dst_tp_name = forward_convert_tp_name(src_node, index + 1)

          # forward
          @tp_name_table[src_node.name][src_tp.name] = dst_tp_name unless key_node_tp?(src_node.name, src_tp.name)
          # reverse
          @tp_name_table[dst_node_name][dst_tp_name] = src_tp.name unless key_node_tp?(dst_node_name, dst_tp_name)
        end
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    # @param [Netomox::Topology::Node] src_node Source node
    # @return [String] Converted node name
    def forward_convert_node_name(src_node)
      src_node.name # not convert
    end

    # @return [void]
    def make_node_name_table
      src_nw = @src_nws.find_network('layer3')
      src_nw.nodes.each do |src_node|
        dst_node_name = forward_convert_node_name(src_node)

        # forward
        @node_name_table[src_node.name] = dst_node_name unless key_node?(src_node.name)
        # reverse
        @node_name_table[dst_node_name] = src_node.name unless key_node?(dst_node_name)
      end
    end

    # @param [String] file Topology file path
    # @return [Netomox::Topology::Networks]
    def read_networks(file)
      raw_data = JSON.parse(File.read(file))
      Netomox::Topology::Networks.new(raw_data)
    end
  end
end
