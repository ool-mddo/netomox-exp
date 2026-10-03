# frozen_string_literal: true

require 'netomox'

module NetomoxExp
  module ConvertNamespace
    # Base class of namespace converter
    class NamespaceConverterBase
      def initialize
        # NOTE: initialized with #load_origin_topology
        #   #convert_all_hash_keys and related methods are used in children: NamespaceConverter and UpperLayer3Filter.
        #   Each class has different condition to initialize itself.
        # @see ConvertNamespace#reload
        #   It can make a instance of NamespaceConvertTable. It instance has two method to initialize:
        #   1. Give it topology data (initialize from RFC8345 json)
        #   2. Reload old convert table without topology data
        @src_nws = nil
        @src_node_flags = {}
      end

      # @param [Hash] topology_data Topology data (RFC8345 Hash)
      # @return [void]
      def load_origin_topology(topology_data)
        @src_nws = Netomox::Topology::Networks.new(topology_data)
        @src_nws.clear_diff_state
        @upper_l3_nw_names = upper_layer3_network_names
        @src_node_flags = extract_node_flags(topology_data)
      end

      protected

      # NOTE: The top-level `flag` of a node (RFC8345 node, e.g. `"flag": ["firewall"]`) is not handled by netomox gem.
      #   (Netomox::Topology::Node drops it, and the converted/filtered topology does not have it.)
      #   The flag must be kept as it is before and after the conversion, so it is restored from the source data.

      # @param [Hash] topology_data Topology data (RFC8345 Hash)
      # @return [Hash{String => Hash{String => Array<String>}}] network-id => node-id => top-level flags
      def extract_node_flags(topology_data)
        networks = topology_data.dig('ietf-network:networks', 'network') || []
        networks.to_h do |nw|
          flags = (nw['node'] || []).reject { |node| node.fetch('flag', []).empty? }
                                    .to_h { |node| [node['node-id'], node['flag']] }
          [nw['network-id'], flags]
        end
      end

      # @param [Hash] topo_data Converted/filtered topology data (RFC8345 Hash, to be updated)
      # @yield [network_id, node_id] Block to find the source node-id from a node-id of topo_data
      # @yieldparam [String] network_id Network id
      # @yieldparam [String] node_id Node id in topo_data
      # @yieldreturn [String, nil] Node id in the source topology data
      # @return [Hash] topo_data (node top-level flags are restored)
      def restore_node_flags(topo_data)
        topo_data.dig('ietf-network:networks', 'network')&.each do |nw|
          src_flags = @src_node_flags[nw['network-id']] || {}
          (nw['node'] || []).each do |node|
            flags = src_flags[yield(nw['network-id'], node['node-id'])]
            node['flag'] = flags.dup if flags
          end
        end
        topo_data
      end

      # @return [Array<String>] Network names (upper layer3)
      def upper_layer3_network_names
        nw_names = Netomox::UPPER_LAYER3_NWTYPE_LIST.map do |network_type|
          @src_nws&.find_all_networks_by_type(network_type)&.map(&:name)
        end
        nw_names.flatten.compact
      end

      # @param [String] network_name Network (layer) name
      # @return [Boolean] True if the network name is a one of upper layer3 network names
      def target_network?(network_name)
        # NOTE: network NAME is used to detect the network is target or not.
        #   because it must be detect supporting-foo, that is object reference.
        @upper_l3_nw_names.include?(network_name)
      end
    end
  end
end
