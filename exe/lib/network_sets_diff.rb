# frozen_string_literal: true

require 'forwardable'
require 'json'
require 'netomox'
require_relative './disconnected_verifiable_networks'

# handle subtract (diff) information of NetworkSets
class NetworkSetsDiff
  attr_reader :orig_file, :orig_sets, :target_file, :target_sets, :compared

  extend Forwardable
  def_delegators :@compared, :[]

  # @param [String] orig_file Original topology file path
  # @param [String] target_file Target topology file path
  def initialize(orig_file, target_file)
    @orig_file = orig_file
    @orig_sets = disconnected_check(orig_file)
    @target_file = target_file
    @target_sets = disconnected_check(target_file)
    # Hash, { network_name: { subsets_count_diff: Integer, elements_diff: Array<String> }}
    # @see NetworkSets#-, NetworkSets#subtract_result
    @compared = orig_sets - target_sets
  end

  # @return [Hash]
  def to_data
    print_datum1 = {
      target_file: @target_file,
      score: calculate_score
    }
    print_datum2 = @compared.each_key.to_h do |nw_name|
      [nw_name, network_datum(nw_name)] # to hash [key, value]
    end
    print_datum1.merge(print_datum2)
  end

  private

  # @param [String] file_path Topology file path
  # @return [NetworkSets] Network sets
  def disconnected_check(file_path)
    raw_topology_data = JSON.parse(File.read(file_path))
    nws = Netomox::Topology::DisconnectedVerifiableNetworks.new(raw_topology_data)
    nws.find_all_network_sets
  end

  # @return [Integer] total score
  def calculate_score
    @compared.values.inject(0) do |sum, nw_result|
      sum + (nw_result[:subsets_count_diff] * 10) + nw_result[:elements_diff].length
    end
  end

  # @param [String] nw_name Network name
  # @return [Hash]
  def network_datum(nw_name)
    {
      subsets_count_diff: @compared[nw_name][:subsets_count_diff],
      elements_diff_count: @compared[nw_name][:elements_diff].length,
      elements_diff: @compared[nw_name][:elements_diff]
    }
  end
end
