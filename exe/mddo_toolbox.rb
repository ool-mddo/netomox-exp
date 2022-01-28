#!/usr/bin/env ruby
# frozen_string_literal: true

require 'csv'
require 'json'
require 'thor'
require 'yaml'
require_relative 'l1_descr/l1_intf_descr_checker'
require_relative 'l1_descr/l1_intf_descr_maker'
require_relative 'nw_subsets/network_sets_diff'
require_relative 'reach_test/reach_tester'
require_relative 'reach_test/reach_result_converter'

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
    # @param [String] target_file Topology file to read
    # @return [void]
    def make_l1_descr(target_file)
      maker = L1InterfaceDescriptionMaker.new(target_file)
      print_csv(maker.full_table)
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

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    desc 'test_reachability PATTERN_FILE', 'Test L3 reachability with pattern file'
    method_option :network, aliases: :n, required: true, type: :string, desc: 'network name in batfish'
    method_option :format, aliases: :f, default: 'yaml', type: :string, enum: %w[yaml json csv],
                           desc: 'Output format (to stdout, ignored with --run_test)'
    method_option :run_test, aliases: :r, default: '', type: :string, desc: 'Save result to file (json) and run test'
    # @param [String] file Test pattern def file (yaml)
    # @return [void]
    def test_reachability(file)
      tester = ReachTester.new(file)
      reach_results = tester.exec_all_tests(options[:network])
      converter = ReachResultConverter.new(reach_results)
      reach_results_summary = converter.summary
      if options[:run_test].empty?
        options[:format] == 'csv' ? print_csv(converter.full_table) : print_data(reach_results_summary)
      else
        file = options[:run_test]
        detail_file = "#{File.basename(file, '.*')}.detail#{File.extname(file)}"
        # save test result (detail/summary)
        print_json_data_to_file(reach_results, detail_file)
        print_json_data_to_file(reach_results_summary, file)
        # test_traceroute_result.rb reads fixed file name
        print_json_data_to_file(reach_results_summary, '.traceroute_result.json')
        exec("bundle exec ruby #{__dir__}/reach_test/test_traceroute_result.rb")
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

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

    # @param [Object] data Data to print as json
    # @return [String] file_name File name to write
    # @return [void]
    def print_json_data_to_file(data, file_name)
      File.open(file_name, 'w') do |file|
        JSON.dump(data, file)
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
