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
require_relative 'convert_namespace/converter'
require_relative 'convert_topology/batfish_converter'
require_relative 'convert_topology/containerlab_converter'

module TopologyOperator
  # rubocop:disable Metrics/ClassLength

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
    method_option :snapshot_re, aliases: :s, type: :string, default: '.*', desc: 'snapshot name (regexp)'
    method_option :format, aliases: :f, default: 'yaml', type: :string, enum: %w[yaml json csv],
                           desc: 'Output format (to stdout, ignored with --run_test)'
    method_option :run_test, aliases: :r, type: :boolean, default: false, desc: 'Save result to files and run test'
    # @param [String] file Test pattern def file (yaml)
    # @return [void]
    def test_reachability(file)
      tester = ReachTester.new(file)
      reach_results = tester.exec_all_traceroute_tests(options[:network], options[:snapshot_re])
      converter = ReachResultConverter.new(reach_results)
      reach_results_summary = converter.summary
      # for debug: without -r option, print data and exit
      unless options[:run_test]
        options[:format] == 'csv' ? print_csv(converter.full_table) : print_data(reach_results_summary)
        exit 0
      end

      file_base = options[:network]
      summary_json_file = "#{file_base}.test_summary.json"
      detail_json_file = "#{file_base}.test_detail.json"
      summary_csv_file = "#{file_base}.test_summary.csv"
      # save test result (detail/summary)
      print_json_data_to_file(reach_results, detail_json_file)
      print_json_data_to_file(reach_results_summary, summary_json_file)
      print_csv_data_to_file(converter.full_table, summary_csv_file)
      # test_traceroute_result.rb reads fixed file name
      print_json_data_to_file(reach_results_summary, '.test_detail.json')
      exec("bundle exec ruby #{__dir__}/reach_test/test_traceroute_result.rb -v silent")
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

    # rubocop:disable Metrics/AbcSize
    desc 'convert_namespace TOPOLOGY', 'Convert namespace of topology file (L3+)'
    method_option :table, aliases: :t, type: :string, desc: 'convert table file'
    method_option :overwrite, aliases: :o, type: :boolean, default: false, desc: 'Overwrite convert table'
    method_option :format, aliases: :f, default: 'yaml', type: :string, enum: %w[yaml json],
                           desc: 'Output format (to stdout)'
    # @param [String] file Target topology file path
    # @return [void]
    def convert_namespace(file)
      converter = NamespaceConverter.new(file)
      table_file = options.key?(:table) ? options[:table] : File.join(Dir.pwd, 'ns_table.json')

      if !options[:overwrite] && File.exist?(table_file)
        converter.reload_convert_table(table_file)
      else
        converter.make_convert_table
        print_json_data_to_file(converter.convert_table, table_file)
      end
      print_data(converter.convert)
    end
    # rubocop:enable Metrics/AbcSize

    desc 'convert_topology TOPOLOGY', 'Convert topology for container-lab/batfish'
    method_option :target, aliases: :t, type: :string, enum: %w[clab bf], required: true,
                           desc: 'Output target: container-lab/batfish'
    method_option :format, aliases: :f, default: 'yaml', type: :string, enum: %w[yaml json], desc: 'Output format'
    method_option :source, aliases: :s, type: :string, required: true, desc: 'Source network (layer) name'
    method_option :env_name, aliases: :e, type: :string, default: 'emulated', desc: 'Environment name (for clab)'
    # @param [String] file Target topology file path
    # @return [void]
    def convert_topology(file)
      converter = if options[:target] == 'bf'
                    BatfishConverter.new(file, options[:source])
                  else
                    ContainerLabConverter.new(file, options[:source], { env_name: options[:env_name] })
                  end
      print_data(converter.convert)
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

    # @param [Array<Array>] data Table data: [[header cols],[data],...]
    # @param [String] file_name File name to write
    # @return [void]
    def print_csv_data_to_file(data, file_name)
      CSV.open(file_name, 'wb') do |csv_out|
        data.each { |row| csv_out << row }
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end

# start CLI tool
TopologyOperator::MddoToolbox.start(ARGV)
