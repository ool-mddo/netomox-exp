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
      end

      # @param [Hash] topology_data Topology data (RFC8345 Hash)
      # @return [void]
      def load_origin_topology(topology_data)
        @src_nws = Netomox::Topology::Networks.new(topology_data)
        @src_nws.clear_diff_state
        @upper_l3_nw_names = upper_layer3_network_names
      end

      protected

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
