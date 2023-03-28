# frozen_string_literal: true

require_relative 'convert_table_base'

module NetomoxExp
  # Node name convert table
  class NodeNameTable < ConvertTableBase
    # @param [String] src_node_name Source node name
    # @return [String]
    # @raise [StandardError]
    def convert(src_node_name)
      raise StandardError, "Node name: #{src_node_name} is not in node-table" unless key_in_table?(src_node_name)

      @convert_table[src_node_name]
    end

    # @param [String] node_name Node name
    # @return [Boolean] True if the node name is in node table key
    def key_in_table?(node_name)
      @convert_table.key?(node_name)
    end

    # @param [Netomox::Topology::Networks] src_nws Source networks
    # @return [void]
    def make_table(src_nws)
      super(src_nws)
      src_nw = @src_nws.find_network('layer3')
      src_nw.nodes.each do |src_node|
        # forward (src -> dst) node name conversion
        dst_node_name = forward_convert_node_name(src_node)

        # forward
        @convert_table[src_node.name] = dst_node_name unless key_in_table?(src_node.name)
        # reverse
        @convert_table[dst_node_name] = src_node.name unless key_in_table?(dst_node_name)
      end
    end

    private

    # @param [Netomox::Topology::Node] src_node Source node
    # @return [String] Converted node name
    def forward_convert_node_name(src_node)
      src_node.name # not convert
    end
  end
end
