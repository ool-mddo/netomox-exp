#!/usr/bin/env ruby
# frozen_string_literal: true

require 'csv'
require 'json'
require 'thor'
require 'yaml'
require_relative 'lib/l1_intf_descr_checker'
require_relative 'lib/l1_intf_descr_maker'
require_relative 'lib/network_sets_diff'
require_relative 'lib/reach_tester'
require_relative 'lib/reach_result_converter'

module TopologyOperator
  # Tools to operate topology data (CLI frontend)
  class MddoToolbox < Thor
    package_name 'mddo_toolbox'

    desc 'check_l1_descr [options] TOPOLOGY', 'Check interface descriptions in layer1 topology'
    method_option :format, aliases: :f, default: 'yaml', type: :string, enum: %w[yaml json], desc: 'Output format'
    method_option :level, aliases: :l, default: 'info', type: :string, enum: %w[info warning error],
                          desc: 'Output level'
    # @param [String] target_file Topology file path to check
    # @return [void]
    def check_l1_descr(target_file)
      checker = L1InterfaceDescriptionChecker.new(target_file)
      print_data(checker.check(options[:level]))
    end

    desc 'make_l1_descr [options] TOPOLOGY', 'Make interface description from layer1 topology'
    method_option :output, aliases: :o, type: :string, desc: 'Output to file (CSV)'
    # @param [String] target_file Topology file to read
    # @return [void]
    def make_l1_descr(target_file)
      maker = L1InterfaceDescriptionMaker.new(target_file)
      maker.make(options[:output] || '')
    end

    desc 'compare_subsets [options] BEFORE_TOPOLOGY AFTER_TOPOLOGY', 'Compare topology data before linkdown'
    method_option :min_score, aliases: :m, default: 0, type: :numeric, desc: 'Minimum score to print'
    method_option :format, aliases: :f, default: 'yaml', type: :string, enum: %w[yaml json], desc: 'Output format'
    # @param [String] orig_file Original topology file path
    # @param [Array<String>] target_files Target topology file path
    # @return [void]
    def compare_subsets(orig_file, *target_files)
      network_sets_diffs = target_files.sort.map do |target_file|
        NetworkSetsDiff.new(orig_file, target_file)
      end
      data = network_sets_diffs.map(&:to_data).reject { |d| d[:score] < options[:min_score] }
      print_data(data)
    end

    desc 'get_subsets [options] TOPOLOGY', 'Get subsets for each network in the topology'
    method_option :format, aliases: :f, default: 'yaml', type: :string, enum: %w[yaml json], desc: 'Output format'
    # @param [String] file Topology file path
    # @return [void]
    def get_subsets(file)
      nws = TopologyOperator.read_topology_data(file)
      print_data(nws.find_all_network_sets.to_array)
    end

    desc 'test_reachability PATTERN_FILE', 'Test L3 reachability with pattern file'
    method_option :network, aliases: :n, default: 'pushed_configs', type: :string, desc: 'network name in batfish'
    method_option :format, aliases: :f, default: 'yaml', type: :string, enum: %w[yaml json csv], desc: 'Output format'
    # @param [String] file Topology file path
    # @return [void]
    def test_reachability(file)
      tester = ReachTester.new(file)
      reach_results = tester.exec_all_tests(options[:network])
      # print_data(reach_results)
      rconv = ReachResultConverter.new(reach_results)
      if options[:format] == 'csv'
        print_csv(rconv.full_table)
      else
        print_data(rconv.summary)
      end
    end

    private

    # @param [Object] data Data to print
    # @return [void]
    def print_data(data)
      case options[:format]
      when 'yaml'
        puts YAML.dump(data)
      when 'json'
        puts JSON.pretty_generate(data)
      else
        warn "Unknown format option: #{options[:format]}"
        exit 1
      end
    end

    # @param [Array<Array>] data Table data: [[header cols],[data],...]
    # @return [void]
    def print_csv(data)
      CSV do |csv_out|
        data.each { |row| csv_out << row }
      end
    end
  end
end

# start CLI tool
TopologyOperator::MddoToolbox.start(ARGV)
