#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'thor'
require 'yaml'
require_relative './lib/disconnected_verifiable_networks'

# class to find disconnected network and compare its origin
class DisconnectedNetworkChecker < Thor
  package_name 'disconnected_network_checker'

  desc 'compare BEFORE AFTER', 'compare model data before linkdown'
  method_option :min_score, aliases: :m, default: 0, type: :numeric, desc: 'Minimum score to print'
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
    puts YAML.dump(print_data.reject { |d| d[:score] < options[:min_score] })
  end

  # rubocop:disable Metrics/MethodLength
  # @param [Hash] compared_result
  # @return [Hash]
  def construct_print_datum(compared_result)
    score = score_from(compared_result)
    print_datum = {
      target_file: compared_result[:target],
      score: score
    }
    compared_result[:compare].each_key do |network|
      r_nw = compared_result[:compare][network]
      print_datum[network] = {
        subsets_diff_count: r_nw[:subsets_diff_count],
        elements_diff_count: r_nw[:elements_diff].length,
        elements_diff: r_nw[:elements_diff]
      }
    end
    print_datum
  end
  # rubocop:enable Metrics/MethodLength

  # @param [Hash] compared_result
  # @return [Integer] total score
  def score_from(compared_result)
    compared_result[:compare].keys.inject(0) do |sum, network|
      r_nw = compared_result[:compare][network]
      sum + (r_nw[:subsets_diff_count] * 10) + r_nw[:elements_diff].length
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

## main
DisconnectedNetworkChecker.start(ARGV)
