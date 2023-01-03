# frozen_string_literal: true
require 'json'
require 'yaml'
require 'netomox'

module TopologyOperator
  # namespace converter
  class NamespaceConverter
    # @param [String] file Topology file path
    def initialize(file)
      @src_nws = read_networks(file)
      @node_name_table = {}
      @tp_name_table = {}
      filter_over_layer3
      make_convert_table
    end

    # @return [Hash]
    def to_data
      @src_nws.to_data
    end

    private

    # @return [void]
    def make_convert_table
      make_node_name_table
      make_tp_name_table
      warn YAML.dump({ 'node_name_table' => @node_name_table, 'tp_name_table' => @tp_name_table })
    end

    # @param [Netomox::Topology::Node] src_node Source node (L3)
    # @param [Integer] index Term-point index
    # @return [String] Converted term-point name
    def forward_convert_tp_name(src_node, index)
      return "#{src_node.name.tr('_/', '-').downcase}_Ethernet#{index}" if src_node.attribute.node_type == 'segment'

      "eth#{index}.0"
    end

    # @return [void]
    def make_tp_name_table
      src_nw = @src_nws.find_network('layer3')
      src_nw.nodes.each do |src_node|
        dst_node_name = @node_name_table[src_node.name]

        # forward
        @tp_name_table[src_node.name] = {} unless @tp_name_table.key?(src_node.name)
        # reverse
        @tp_name_table[dst_node_name] = {} unless @tp_name_table.key?(dst_node_name)

        src_node.termination_points.sort { |tp1, tp2| tp1.name <=> tp2.name }.each_with_index do |src_tp, index|
          dst_tp_name = forward_convert_tp_name(src_node, index + 1)

          # forward
          unless @tp_name_table[src_node.name].key?(src_tp.name)
            @tp_name_table[src_node.name][src_tp.name] = dst_tp_name
          end
          # reverse
          unless @tp_name_table[dst_node_name].key?(dst_tp_name)
            @tp_name_table[dst_node_name][dst_tp_name] = src_tp.name
          end
        end
      end
    end

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
        @node_name_table[src_node.name] = dst_node_name unless @node_name_table.key?(src_node.name)
        # reverse
        @node_name_table[dst_node_name] = src_node.name unless @node_name_table.key?(dst_node_name)
      end
    end

    # @return [void]
    def filter_over_layer3
      layer_regexp_list = %w[ospf_area0 layer3]
      @src_nws.networks.delete_if { |nw| !layer_regexp_list.include?(nw.name) }
    end

    # @param [String] file Topology file path
    # @return [Netomox::Topology::Networks]
    def read_networks(file)
      raw_data = JSON.parse(File.read(file))
      Netomox::Topology::Networks.new(raw_data)
    end
  end
end
