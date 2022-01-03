#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'thor'
require 'yaml'
require_relative './lib/disconnected_verifiable_networks'

# class to find disconnected network and compare its origin
class DisconnectedNetworkChecker < Thor
  package_name 'disconnected_network_checker'

  desc 'compare [options] BEFORE_TOPOLOGY AFTER_TOPOLOGY', 'Compare topology data before linkdown'
  method_option :min_score, aliases: :m, default: 0, type: :numeric, desc: 'Minimum score to print'
  method_option :format, aliases: :f, default: 'yaml', type: :string, enum: %w[yaml json], desc: 'Output format'
  # @param [String] orig_file Original topology file path
  # @param [Array<String>] target_files Target topology file path
  def compare(orig_file, *target_files)
    orig_sets = disconnected_check(orig_file)
    compared_results = target_files.sort.map do |target_file|
      collect_compared_results(orig_file, target_file, orig_sets)
    end
    print_compared_results(compared_results)
  end

  private

  # @param [Array<Hash>] compared_results
  # @return [void]
  def print_compared_results(compared_results)
    print_data = compared_results.map do |compared_result|
      construct_print_datum(compared_result)
    end
    filtered_print_data = print_data.reject { |d| d[:score] < options[:min_score] }
    puts options[:format] == 'yaml' ? YAML.dump(filtered_print_data) : JSON.pretty_generate(filtered_print_data)
  end

  # @param [Hash] compared_result
  # @return [Hash]
  def construct_print_datum(compared_result)
    score = score_from(compared_result)
    print_datum1 = {
      target_file: compared_result[:target],
      score: score
    }
    print_datum2 = compared_result[:compare].each_key.to_h do |network|
      [network, print_datum_for_network(compared_result[:compare][network])] # to hash [key, value]
    end
    print_datum1.merge(print_datum2)
  end

  # @param [Hash] nw_result a network part of compared_result
  # @return [Hash]
  def print_datum_for_network(nw_result)
    {
      subsets_count_diff: nw_result[:subsets_count_diff],
      elements_diff_count: nw_result[:elements_diff].length,
      elements_diff: nw_result[:elements_diff]
    }
  end

  # @param [Hash] compared_result
  # @return [Integer] total score
  def score_from(compared_result)
    compared_result[:compare].keys.inject(0) do |sum, network|
      nw_result = compared_result[:compare][network]
      sum + (nw_result[:subsets_count_diff] * 10) + nw_result[:elements_diff].length
    end
  end

  # @param [String] orig_file Original topology file path
  # @param [String] target_file Target topology file path
  # @param [NetworkSets] orig_sets Network sets of original topology file
  # @return [Hash]
  def collect_compared_results(orig_file, target_file, orig_sets)
    target_sets = disconnected_check(target_file)
    {
      origin: orig_file,
      target: target_file,
      compare: orig_sets - target_sets
    }
  end

  # @param [String] file_path Topology file path
  # @return [NetworkSets] Network sets
  def disconnected_check(file_path)
    raw_topology_data = JSON.parse(File.read(file_path))
    nws = Netomox::Topology::DisconnectedVerifiableNetworks.new(raw_topology_data)
    nws.find_all_network_sets
  end
end

# start CLI tool
DisconnectedNetworkChecker.start(ARGV)
