# frozen_string_literal: true

# Networks  .........................  NetworkSets
#   + Network (layer)  ................. + NetworkSet
#       + Sub-network (sub-graph)  ........  * NetworkSubset

# Network subset: connected network elements (node/tp) in a network (layer)
class NetworkSubset
  # @!attribute [r] elements
  #   return [Array<String>]
  attr_reader :elements

  extend Forwardable
  # @!method push
  #   @see Array#push
  # @!method to_s
  #   @see Array#to_s
  # @!method include?
  #   @see Array#include?
  def_delegators :@elements, :push, :to_s, :include?

  # @param [Array<String>] element_paths Paths of node/term-point
  def initialize(*element_paths)
    @elements = element_paths || []
  end

  # @return [NetworkSubset] self
  def uniq!
    @elements.uniq!
    self
  end
end

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

  private

  # @param [NetworkSet] orig_set
  # @param [NetworkSet] target_set
  # @return [Hash]
  def subtract_result(orig_set, target_set)
    {
      subsets_count_diff: orig_set.length - target_set.length,
      elements_diff: orig_set - target_set
    }
  end
end
