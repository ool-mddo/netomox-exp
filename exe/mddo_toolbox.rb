#!/usr/bin/env ruby
# frozen_string_literal: true

require 'csv'
require 'json'
require 'thor'
require 'yaml'
require_relative 'l1_descr/l1_intf_descr_checker'
require_relative 'l1_descr/l1_intf_descr_maker'

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
