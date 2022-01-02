#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'thor'
require_relative './disconnected_verifiable_networks'

class DisconnectedNetworkChecker < Thor
  package_name "disconnected_network_checker"

  desc 'compare BEFORE AFTER', 'compare model data before linkdown'
  method_option :min_score, aliases: :m, default: 0, type: :numeric, desc: 'Minimum score to print'
  def compare(orig_file, *target_files)
    origin_disconn_result = disconnected_check(orig_file)
    compared_results = target_files.sort.map do |target_file|
      target_disconn_result = disconnected_check(target_file)
      {
        origin: orig_file,
        target: target_file,
        compare: subtract_results(origin_disconn_result, target_disconn_result)
      }
    end

    puts "# compare results"
    compared_results.each do |compared_result|
      puts "- #{compared_result[:target]}"
      score = compared_result[:compare].keys.inject(0) do |sum, network|
        r_nw = compared_result[:compare][network]
        sum + r_nw[:sub_graph_diff] * 10 + r_nw[:element_diff].length
      end
      next if score < options[:min_score]
      puts "  - score: #{score}"
      compared_result[:compare].keys.each do |network|
        r_nw = compared_result[:compare][network]
        puts "  - #{network.to_s}"
        puts "    - diff: #{r_nw[:sub_graph_diff]}"
        puts "    - changed_count: #{r_nw[:element_diff].length}"
        puts "    - changed: #{r_nw[:element_diff]}"
      end
    end
  end

  private

  def find_by_network(result, network_name)
    result.find { |r| r[:network] == network_name }
  end

  def subtract_elements(orig_elms, target_elms)
    orig_elms = orig_elms.inject([]) { |union, subgraph| union | subgraph }
    target_elms = target_elms.inject([]) { |union, subgraph| union | subgraph }
    # elements only in original
    orig_elms - target_elms
  end

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

  def disconnected_check(file_path)
    raw_topology_data = JSON.parse(File.read(file_path))
    nws = Netomox::Topology::DisconnectedVerifiableNetworks.new(raw_topology_data)
    nws.find_all_disconnected_sub_graphs
  end
end

## main
DisconnectedNetworkChecker.start(ARGV)
