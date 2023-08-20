# frozen_string_literal: true

require_relative 'convert_table_base'

module NetomoxExp
  module NamespaceConvertTable
    # Node name convert table
    class NodeNameTable < ConvertTableBase
      # @param [String] src_node_name Source node name
      # @return [Hash] node name dic
      # @raise [StandardError]
      def convert(src_node_name)
        raise StandardError, "Node name: #{src_node_name} is not in node-table" unless key_in_table?(src_node_name)

        # key string is "L3 model name"
        #
        # original_node_name => {                            # <= converted name dictionary
        #   'l3_model' => 'emulated_node_name (L3 model)',
        #   'l1_agent' => 'emulated_node_name (emulated env L1 config, cEOS for segment-node)',
        #   'l1_principal' => 'emulated_node_name (emulated env instance, OVS for segment-node)'
        # }
        # NOTE: L3 node name is not converted, then backward conversion entry is itself (key:l3)
        # NOTE: all keys must be String, because string node name is used as dictionary key.
        #   if reload the table from file, ALL keys will be string or symbol...
        @convert_table[src_node_name]
      end

      # @param [String] l3_node_name Node name (L3) (original/emulated)
      # @return [String,nil] Node name (emulated/original)
      def reverse_lookup(l3_node_name)
        @convert_table.keys.find { |node| @convert_table[node]['l3_model'] == l3_node_name }
      end

      # @param [String] l3_node_name Node name (L3)
      # @return [Hash] Node name dic
      def find_l1_alias(l3_node_name)
        @convert_table[reverse_lookup(l3_node_name)]
      end

      # @param [String] node_name Node name
      # @return [Boolean] True if the node name is in node table key
      def key_in_table?(node_name)
        @convert_table.key?(node_name)
      end

      # rubocop:disable Metrics/AbcSize

      # @param [Netomox::Topology::Network] src_nw Source network (layer3)
      # @return [void]
      # @raise [StandardError] if target layer is not found
      def make_layer3_node_table(src_nw)
        raise StandardError, 'Network: layer3 is not found' if src_nw.nil?

        segment_node_count = -1
        src_nw.nodes.each do |src_node|
          segment_node_count += 1 if segment_node?(src_node)
          # forward (src -> dst) node name conversion
          dst_node_dic = forward_convert_node_name(src_node, segment_node_count)

          # forward
          @convert_table[src_node.name] = dst_node_dic unless key_in_table?(src_node.name)
          # reverse
          unless key_in_table?(dst_node_dic['l3_model'])
            @convert_table[dst_node_dic['l3_model']] = emulated_name_dict(src_node.name)
          end
        end
      end
      # rubocop:enable Metrics/AbcSize

      # @param [Netomox::Topology::Network] src_nw Source network (bgp-proc/as)
      # @return [void]
      def make_pass_through_node_table(src_nw)
        # nothing to do if target layer is not found
        return if src_nw.nil?

        src_nw.nodes.each do |src_node|
          next if @convert_table.key?(src_node.name)

          # pass-through (do not convert)
          @convert_table[src_node.name] = pass_through_name_dict(src_node.name)
        end
      end

      # @param [Netomox::Topology::Networks] src_nws Source networks
      # @return [void]
      def make_table(src_nws)
        super(src_nws)
        # convert table (for layer3, ospf-area)
        make_layer3_node_table(@src_nws.find_network('layer3'))

        # convert table (not converted: for bgp-proc, bgp-as)
        %w[bgp_proc bgp_as].each do |nw_name|
          make_pass_through_node_table(@src_nws.find_network(nw_name))
        end
      end

      private

      # @param [Netomox::Topology::Node] src_node Source node
      # @param [Integer] segment_node_count Number of segment node
      # @return [Hash] Converted node name
      def forward_convert_node_name(src_node, segment_node_count)
        if segment_node?(src_node)
          l1_agent = src_node.name.gsub(%r{[/_]}, '-')
          l1_principal = "br#{segment_node_count}"
          return emulated_name_dict(src_node.name, l1_agent:, l1_principal:)
        end

        # other node (actual node)
        emulated_name_dict(src_node.name)
      end
    end
  end
end
