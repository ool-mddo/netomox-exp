# frozen_string_literal: true

# Networks  .........................  NetworkSets
#   + Network (layer)  ................. + NetworkSet
#       + Sub-network (sub-graph)  ........  * NetworkSubset

module TopologyOperator
  # network sets: network sets
  class NetworkSets
    # @!attribute [r] network\sets
    #   @return [Array<NetworkSet>]
    attr_reader :sets

    # @param [Array<Netomox::Topology::Network>] networks Networks
    def initialize(networks)
      @sets = networks.map(&:find_all_subsets)
    end

    # @param [String] name Network name to find
    # @return [nil, NetworkSet] Found network-set
    def network(name)
      @sets.find { |set| set.network_name == name }
    end

    # @param [NetworkSets] other
    # @return [Hash]
    # @raise [StandardError]
    def -(other)
      @sets.map(&:network_name).to_h do |nw_name|
        orig_set = network(nw_name)
        target_set = other.network(nw_name)
        raise StandardError, 'network name not found in NetworkSet' if orig_set.nil? || target_set.nil?

        [nw_name.intern, subtract_result(orig_set, target_set)] # [key, value] to hash
      end
    end

    # @return [Array<Hash>]
    def to_array
      @sets.map do |set|
        subsets = set.to_array
        {
          network: set.network_name,
          subsets_count: subsets.length,
          subsets: subsets
        }
      end
    end

    private

    # @param [NetworkSet] orig_set
    # @param [NetworkSet] target_set
    # @return [Hash]
    def subtract_result(orig_set, target_set)
      {
        subsets_count_diff: (orig_set.length - target_set.length).abs,
        # NOTE: find decreased elements (elements only in the original)
        # @see NetworkSet#-
        elements_diff: orig_set - target_set
      }
    end
  end
end
