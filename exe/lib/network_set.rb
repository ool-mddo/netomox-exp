# frozen_string_literal: true

module TopologyOperator
  # Network set: network subsets in a network (layer)
  class NetworkSet
    # @!attribute [r] network_name
    #   @return [String]
    # @!attribute [r] subsets
    #   @return [Array<NetworkSubset>]
    attr_reader :network_name, :subsets

    extend Forwardable
    # @!method push
    #   @see Array#push
    # @!method to_s
    #   @see Array#to_s
    # @!method length
    #   @see Array#length
    def_delegators :subsets, :push, :to_s, :length

    # @param [String] network_name Network name
    def initialize(network_name)
      @network_name = network_name
      @subsets = []
    end

    # @param [String] element_path Path of node/term-point to search
    # @return [nil, NetworkSubset] Found network subset
    def find_subset_includes(element_path)
      @subsets.find { |ss| ss.include?(element_path) }
    end

    # @return [Array<String>] Union all subset elements
    def union_subsets
      @subsets.inject([]) { |union, subset| union | subset.elements }
    end

    # @param [NetworkSet] other
    # @return [Array<String>]
    def -(other)
      union_subsets - other.union_subsets
    end
  end
end
