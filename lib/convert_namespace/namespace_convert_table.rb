# frozen_string_literal: true

require 'json'
require 'netomox'
require_relative 'namespace_converter_base'

module NetomoxExp
  # rubocop:disable Metrics/ClassLength

  # convert table
  class NamespaceConvertTable < NamespaceConverterBase
    def initialize
      super
      # NOTE: initialized in #make_convert_table method:
      #   used when construct convert table from topology data
      @src_nws = nil
      # convert tables
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

    # @param [String] src_node_name Source node name
    # @param [Regexp] src_tp_name_re Source term-point name (Regexp)
    # @return [String]
    # @raise [StandardError]
    def convert_tp_name_match(src_node_name, src_tp_name_re)
      raise StandardError, "Node: #{src_node_name} is not in tp-table" unless key_node_tp?(src_node_name)

      matched_tp_names = @tp_name_table[src_node_name].keys.grep(src_tp_name_re)
      converted_tp_names = matched_tp_names.map { |tp| @tp_name_table[src_node_name][tp] }
      # return converted value if it was identified uniquely
      return converted_tp_names[0] if converted_tp_names.length == 1

      raise StandardError, "TP: Regexp #{src_tp_name_re} matches 0 or several term-point(s)"
    end

    # @return [String, Integer] Converted OSPF process id
    # @raise [StandardError]
    def convert_ospf_proc_id(src_node_name, proc_id)
      raise StandardError, "Node: #{src_node_name} is not in ospf-proc-id-table" unless key_ospf_proc_id?(src_node_name)
      raise StandardError, "Proc-ID: #{proc_id} is not in ospf-proc-id-table" unless key_ospf_proc_id?(src_node_name,
                                                                                                       proc_id)

      @ospf_proc_id_table[src_node_name][proc_id]
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

    # @param [String] node_name Node name (OSPF)
    # @param [String, Integer] proc_id OSPF process id
    # @return [Boolean] True if the node and proc_id are in ospf process id table key
    def key_ospf_proc_id?(node_name, proc_id = nil)
      return @ospf_proc_id_table.key?(node_name) if proc_id.nil?

      @ospf_proc_id_table.key?(node_name) && @ospf_proc_id_table[node_name].key?(proc_id)
    end

    # @return [Hash]
    def convert_table
      {
        'node_name_table' => @node_name_table,
        'tp_name_table' => @tp_name_table,
        'ospf_proc_id_table' => @ospf_proc_id_table
      }
    end

    # @param [Netomox::Topology::Networks] topology_data Topology data
    def load_origin_topology(topology_data)
      @src_nws = Netomox::Topology::Networks.new(topology_data)
    end

    # @param [Netomox::Topology::Networks] topology_data Topology data
    # @return [void]
    def make_convert_table(topology_data)
      load_origin_topology(topology_data)
      make_node_name_table # MUST at first (in use making other tables)
      make_tp_name_table
      make_ospf_proc_id_table
    end

    # @param [Hash] given_table_data Convert table data
    # @return [void]
    def reload_convert_table(given_table_data)
      @node_name_table = given_table_data['node_name_table']
      @tp_name_table = given_table_data['tp_name_table']
      @ospf_proc_id_table = given_table_data['ospf_proc_id_table']
    end

    protected

    # @param [Netomox::Topology::Node] node
    def segment_node?(node)
      node.attribute.node_type == 'segment'
    end

    # @param [Netomox::Topology::TermPoint] term_point Term-point (L3)
    # @return [Boolean] True if the tp name is loopback
    def loopback?(term_point)
      !term_point.attribute.empty? && term_point.attribute.flags.include?('loopback')
    end

    private

    # @param [String] src_node Source (original) node name
    # @param [String, Integer] src_proc_id OSPF process id of the source node ("default" or integer)
    # @param [String] dst_node Destination (emulated) node name
    # @param [String, Integer] dst_proc_id OSPF process id of the destination node ("default" or integer)
    # @return [void]
    def add_ospf_proc_id_entry(src_node, src_proc_id, dst_node, dst_proc_id)
      # forward
      @ospf_proc_id_table[src_node] = {} unless key_ospf_proc_id?(src_node)
      @ospf_proc_id_table[src_node][src_proc_id] = dst_proc_id unless key_ospf_proc_id?(src_node, src_proc_id)
      # reverse
      @ospf_proc_id_table[dst_node] = {} unless key_ospf_proc_id?(dst_node)
      @ospf_proc_id_table[dst_node][dst_proc_id] = src_proc_id unless key_ospf_proc_id?(dst_node, dst_proc_id)
    end

    # @return [void]
    def make_ospf_proc_id_table
      src_nw = @src_nws.find_network('ospf_area0')
      src_nw.nodes.each do |src_node|
        dst_node_name = convert_node_name(src_node.name)
        src_proc_id = src_node.attribute.process_id
        dst_proc_id = 'default' # to cRPD ospf (fixed)
        add_ospf_proc_id_entry(src_node.name, src_proc_id, dst_node_name, dst_proc_id)
      end
    end

    # @param [Netomox::Topology::Node] src_node Source node (L3)
    # @param [Integer] index Term-point index
    # @return [String] Converted term-point name
    def forward_convert_tp_name(src_node, index)
      # A term-point of segment node is veth for emulated env on container host
      # all veth in bridges must be unique on the host OS
      return "#{@node_name_table[src_node.name]}eth#{index}" if segment_node?(src_node)

      # for other actual node (some container in emulated env)
      "eth#{index}.0"
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength

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
    def add_tp_name_hash(src_node_name, dst_node_name)
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
        add_tp_name_hash(src_node.name, dst_node_name)

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

    # rubocop:disable Metrics/MethodLength

    # @return [void]
    def make_node_name_table
      seg_node_count = -1 # start 0
      src_nw = @src_nws.find_network('layer3')
      src_nw.nodes.each do |src_node|
        # forward (src -> dst) node name conversion
        dst_node_name = if src_node.attribute.node_type == 'segment'
                          # segment node in emulated env will be OVS bridge,
                          # it has strong name restriction: characters, length<16
                          seg_node_count += 1
                          "br#{seg_node_count}"
                        else
                          src_node.name # not convert
                        end

        # forward
        @node_name_table[src_node.name] = dst_node_name unless key_node?(src_node.name)
        # reverse
        @node_name_table[dst_node_name] = src_node.name unless key_node?(dst_node_name)
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
  # rubocop:enable Metrics/ClassLength
end
