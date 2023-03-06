#!/usr/bin/env ruby
# frozen_string_literal: true

require 'csv'
require 'json'
require 'thor'
require 'yaml'
require_relative 'l1_descr/l1_intf_descr_checker'
require_relative 'l1_descr/l1_intf_descr_maker'
require_relative 'convert_namespace/namespace_converter'
require_relative 'convert_namespace/layer_filter'
require_relative 'convert_topology/batfish_converter'
require_relative 'convert_topology/containerlab_converter'

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

    desc 'filter_low_layers TOPOLOGY', 'Filter (omit) L1/L2 info'
    method_option :format, aliases: :f, default: 'yaml', type: :string, enum: %w[yaml json],
                           desc: 'Output format (to stdout)'
    # @param [String] file Target topology file path
    # @return [void]
    def filter_low_layers(file)
      layer_filter = LayerFilter.new(file)
      print_data(layer_filter.filter)
    end

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
end

# start CLI tool
TopologyOperator::MddoToolbox.start(ARGV)
