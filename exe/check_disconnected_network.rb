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
  def compare(orig_file, *target_files)
    orig_result = disconnected_check(orig_file)
    compared_results = target_files.sort.map do |target_file|
      collect_compared_results(orig_file, target_file, orig_result)
    end
    print_compared_results(compared_results)
  end

  private

  def print_compared_results(compared_results)
    print_data = compared_results.map do |compared_result|
      construct_print_datum(compared_result)
    end
    puts YAML.dump(print_data.reject { |d| d[:score] < options[:min_score] })
  end

  # rubocop:disable Metrics/MethodLength
  def construct_print_datum(compared_result)
    score = score_from(compared_result)
    print_datum = {
      target_file: compared_result[:target],
      score: score
    }
    compared_result[:compare].each_key do |network|
      r_nw = compared_result[:compare][network]
      print_datum[network] = {
        diff: r_nw[:sub_graph_diff],
        changed_count: r_nw[:element_diff].length,
        changed: r_nw[:element_diff]
      }
    end
    print_datum
  end
  # rubocop:enable Metrics/MethodLength

  def score_from(compared_result)
    compared_result[:compare].keys.inject(0) do |sum, network|
      r_nw = compared_result[:compare][network]
      sum + (r_nw[:sub_graph_diff] * 10) + r_nw[:element_diff].length
    end
  end

  def collect_compared_results(orig_file, target_file, orig_result)
    target_result = disconnected_check(target_file)
    {
      origin: orig_file,
      target: target_file,
      compare: subtract_results(orig_result, target_result)
    }
  end

  def find_by_network(result, network_name)
    result.find { |r| r[:network] == network_name }
  end

  def subtract_elements(orig_elms, target_elms)
    orig_elms = orig_elms.inject([]) { |union, subgraph| union | subgraph }
    target_elms = target_elms.inject([]) { |union, subgraph| union | subgraph }
    # elements only in original
    orig_elms - target_elms
  end

  # rubocop:disable Metrics/AbcSize
  def subtract_results(orig_result, target_result)
    compare_data = {}
    orig_result.map { |r| r[:network] }.sort.each do |nw_name|
      orig_layer = find_by_network(orig_result, nw_name)
      target_layer = find_by_network(target_result, nw_name)
      compare_data[nw_name.intern] = {
        sub_graph_diff: orig_layer[:sub_graphs].length - target_layer[:sub_graphs].length,
        element_diff: subtract_elements(orig_layer[:sub_graphs], target_layer[:sub_graphs])
      }
    end
    compare_data
  end
  # rubocop:enable Metrics/AbcSize

  def disconnected_check(file_path)
    raw_topology_data = JSON.parse(File.read(file_path))
    nws = Netomox::Topology::DisconnectedVerifiableNetworks.new(raw_topology_data)
    nws.find_all_disconnected_sub_graphs
  end
end

## main
DisconnectedNetworkChecker.start(ARGV)
