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
  def_delegators :@elements, :push, :to_s, :include?

  def initialize
    @elements = []
  end

  def uniq!
    @elements.uniq!
    self
  end
end

# Network set: network subsets in a network (layer)
class NetworkSet
  # @!attribute [r] network
  #   @return [Netomox::Topology::Network]
  # @!attribute [r] subsets
  #   @return [Array<NetworkSubset>]
  attr_reader :network, :subsets

  # @param [Netomox::Topology::Network] network Network
  def initialize(network)
    @network = network
    @subsets = network.find_all_subsets
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
    @sets = networks.map { |network| NetworkSet.new(network) }
  end

  # @param [String] name Network name to find
  # @return [nil, NetworkSet] Found network-set
  def network(name)
    @sets.find { |set| set.network.name == name }
  end

  # @return [Array<String>] Network name list
  def network_names
    @sets.map { |s| s.network.name }.sort
  end

  # @param [NetworkSets] other
  # @return [Hash]
  def -(other)
    network_names.to_h do |nw_name|
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
      subsets_diff_count: orig_set.subsets.length - target_set.subsets.length,
      elements_diff: orig_set - target_set
    }
  end
end
