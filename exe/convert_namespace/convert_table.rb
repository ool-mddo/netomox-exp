# frozen_string_literal: true

require 'json'
require 'netomox'

module TopologyOperator
  # rubocop:disable Metrics/ClassLength

  # convert table
  class NamespaceConvertTable
    # @param [String] file Topology file path
    def initialize(file)
      @src_nws = read_networks(file)
      @node_name_table = {}
      @tp_name_table = {}
      @ospf_proc_id_table = {}
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
      {
        'node_name_table' => @node_name_table,
        'tp_name_table' => @tp_name_table,
        'ospf_proc_id_table' => @ospf_proc_id_table
      }
    end

    # @return [void]
    def make_convert_table
      make_node_name_table
      make_tp_name_table
      make_ospf_proc_id_table
    end

    # @param [String] file Path of convert table file (json)
    # @return [void]
    def reload_convert_table(file)
      table_data = JSON.parse(File.read(file))
      @node_name_table = table_data['node_name_table']
      @tp_name_table = table_data['tp_name_table']
      @ospf_proc_id_table = table_data['ospf_proc_id_table']
    end

    protected

    # @param [Netomox::Topology::Node] node
    def segment_node?(node)
      node.attribute.node_type == 'segment'
    end

    private

    # rubocop:disable Metrics/AbcSize
    # @return [void]
    def make_ospf_proc_id_table
      src_nw = @src_nws.find_network('ospf_area0')
      src_nw.nodes.each do |src_node|
        dst_node_name = convert_node_name(src_node.name)
        src_proc_id = src_node.attribute.process_id
        dst_proc_id = 'default' # to cRPD ospf (fixed)
        # forward
        @ospf_proc_id_table[src_node.name] = {} unless @ospf_proc_id_table.key?(src_node.name)
        @ospf_proc_id_table[src_node.name][src_proc_id] = dst_proc_id
        # reverse
        @ospf_proc_id_table[dst_node_name] = {} unless @ospf_proc_id_table.key?(dst_node_name)
        @ospf_proc_id_table[dst_node_name][dst_proc_id] = src_proc_id
      end
    end
    # rubocop:enable Metrics/AbcSize

    # @param [Netomox::Topology::Node] src_node Source node (L3)
    # @param [Integer] index Term-point index
    # @return [String] Converted term-point name
    def forward_convert_tp_name(src_node, index)
      return "#{src_node.name.tr('_/', '-').downcase}_Ethernet#{index}" if segment_node?(src_node)

      "eth#{index}.0"
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength

    # @param [Netomox::Topology::TermPoint] term_point Term-point (L3)
    # @return [Boolean] True if the tp name is loopback
    def loopback?(term_point)
      !term_point.attribute.empty? && term_point.attribute.flags.include?('loopback')
    end

    # @param [String] src_node_name Source (original) node name
    # @param [String] src_tp_name Source (original) term-point name
    # @param [String] dst_node_name Destination (converted) node name
    # @param [String] dst_tp_name Destination (converted) term-point name
    # @return [void]
    def add_tp_name_entry(src_node_name, src_tp_name, dst_node_name, dst_tp_name)
      # forward
      @tp_name_table[src_node_name][src_tp_name] = dst_tp_name unless key_node_tp?(src_node_name, src_tp_name)
      # reverse
      @tp_name_table[dst_node_name][dst_tp_name] = src_tp_name unless key_node_tp?(dst_node_name, dst_tp_name)
    end

    # @param [String] src_node_name Source (original) node name
    # @param [String] dst_node_name Destination (converted) node name
    # @return [void]
    def add_tp_name_table_hash(src_node_name, dst_node_name)
      # forward
      @tp_name_table[src_node_name] = {} unless key_node_tp?(src_node_name)
      # reverse
      @tp_name_table[dst_node_name] = {} unless key_node_tp?(dst_node_name)
    end

    # @return [void]
    def make_tp_name_table
      src_nw = @src_nws.find_network('layer3')
      src_nw.nodes.each do |src_node|
        dst_node_name = convert_node_name(src_node.name)
        add_tp_name_table_hash(src_node.name, dst_node_name)

        src_node.termination_points.find_all { |src_tp| loopback?(src_tp) }.each_with_index do |src_tp, index|
          # to cRPD: lo.X
          dst_tp_name = "lo.#{index}"
          add_tp_name_entry(src_node.name, src_tp.name, dst_node_name, dst_tp_name)
        end
        src_node.termination_points.reject { |src_tp| loopback?(src_tp) }.each_with_index do |src_tp, index|
          dst_tp_name = forward_convert_tp_name(src_node, index + 1)
          add_tp_name_entry(src_node.name, src_tp.name, dst_node_name, dst_tp_name)
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
  # rubocop:enable Metrics/ClassLength
end
