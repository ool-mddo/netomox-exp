# frozen_string_literal: true

require_relative 'convert_table_base'

module NetomoxExp
  # Term-point name convert table
  class OspfProcIdTable < ConvertTableBase
    # @param [NodeNameTable] node_name_table
    def initialize(node_name_table)
      super()
      @node_name_table = node_name_table
    end

    # @param [String] src_node_name Source node name
    # @param [String, Integer] proc_id OSPF process id
    # @return [String] Converted OSPF process id (string number or "default")
    # @raise [StandardError]
    def convert(src_node_name, proc_id)
      raise StandardError, "Node: #{src_node_name} is not in ospf-proc-id-table" unless key_in_table?(src_node_name)
      unless key_in_table?(src_node_name, proc_id)
        raise StandardError, "Proc-ID: #{proc_id} in #{src_node_name} is not in ospf-proc-id-table"
      end

      @convert_table[src_node_name][proc_id.to_s]
    end

    # @param [String] node_name Node name (OSPF)
    # @param [String, Integer] proc_id OSPF process id
    # @return [Boolean] True if the node and proc_id are in ospf process id table key
    def key_in_table?(node_name, proc_id = nil)
      return @convert_table.key?(node_name) if proc_id.nil?

      @convert_table.key?(node_name) && @convert_table[node_name].key?(proc_id.to_s)
    end

    # @param [Netomox::Topology::Networks] src_nws Source networks
    # @return [void]
    def make_table(src_nws)
      super(src_nws)
      src_nw = @src_nws.find_network('ospf_area0')
      src_nw.nodes.each do |src_node|
        dst_node_name = @node_name_table.convert(src_node.name)['l3']
        src_proc_id = src_node.attribute.process_id
        dst_proc_id = 'default' # to cRPD ospf (fixed)
        add_ospf_proc_id_entry(src_node.name, src_proc_id, dst_node_name, dst_proc_id)
      end
    end

    private

    # @param [String] src_node Source (original) node name
    # @param [String, Integer] src_proc_id OSPF process id of the source node ("default" or integer)
    # @param [String] dst_node Destination (emulated) node name
    # @param [String, Integer] dst_proc_id OSPF process id of the destination node ("default" or integer)
    # @return [void]
    def add_ospf_proc_id_entry(src_node, src_proc_id, dst_node, dst_proc_id)
      # forward
      @convert_table[src_node] = {} unless key_in_table?(src_node)
      @convert_table[src_node][src_proc_id.to_s] = dst_proc_id.to_s unless key_in_table?(src_node, src_proc_id)
      # reverse
      @convert_table[dst_node] = {} unless key_in_table?(dst_node)
      @convert_table[dst_node][dst_proc_id.to_s] = src_proc_id.to_s unless key_in_table?(dst_node, dst_proc_id)
    end
  end
end
