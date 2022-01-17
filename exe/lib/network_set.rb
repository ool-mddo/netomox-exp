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
    def_delegators :@subsets, :push, :to_s, :length

    # @param [String] network_name Network name
    def initialize(network_name)
      @network_name = network_name
      @subsets = [] # list of network subset
    end

    # @param [String] element_path Path of node/term-point to search
    # @return [nil, NetworkSubset] Found network subset
    def find_subset_includes(element_path)
      @subsets.find { |ss| ss.include?(element_path) }
    end

    # @return [Array] Array of subset-elements
    def to_array
      @subsets.map(&:to_data)
    end

    # @return [NetworkSet] self
    def reject_empty_set!
      @subsets.reject!(&:empty?)
      self
    end

    # @param [NetworkSet] other
    # @return [Array<String>]
    def elements_diff(other)
      # NOTE: For now, the target is a pattern of "link-down".
      #   The original set contains all links, and the target should have fewer components than that.
      #   The result of subtraction does not contains elements which only in the target (increased elements).
      #   e.g. [1,2,3,4,5] - [3,4,5,6,7] # => [1, 2]
      # @see NetworkSets#subtract_result
      union_subset_elements - other.union_subset_elements
    end

    # @param [NetworkSet] other
    # @return [Integer]
    def flag_diff(other)
      union_subset_flags - other.union_subset_flags
    end

    protected

    # @return [Array<String>] Union all subset elements
    def union_subset_elements
      @subsets.inject([]) { |union, subset| union | subset.elements }
    end

    # @param [Integer]
    def union_subset_flags
      @subsets.inject(0) { |sum, subset| sum + subset.flag.keys.filter { |k| subset.flag[k] }.length }
    end
  end
end
