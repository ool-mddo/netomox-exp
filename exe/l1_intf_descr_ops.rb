#!/usr/bin/env ruby
# frozen_string_literal: true

require 'thor'
require 'json'
require 'yaml'
require_relative 'lib/l1_intf_descr_checker'
require_relative 'lib/l1_intf_descr_maker'

# Layer 1 interface description operator (CLI frontend)
class L1InterfaceDescriptionOperator < Thor
  package_name 'l1_intf_description'

  desc 'check [options] TOPOLOGY', 'Check interface descriptions in layer1 topology'
  method_option :format, aliases: :f, default: 'yaml', type: :string, enum: %w[yaml json], desc: 'Output format'
  method_option :level, aliases: :l, default: 'info', type: :string, enum: %w[info warning error], desc: 'Outpu level'
  # @param [String] target_file Topology file path to check
  # @return [void]
  def check(target_file)
    checker = L1InterfaceDescriptionChecker.new(target_file)
    print_data(checker.check(options[:level]))
  end

  desc 'make [options] TOPOLOGY', 'Make interface description from layer1 topology'
  method_option :output, aliases: :o, type: :string, desc: 'Output to file (CSV)'
  # @param [String] target_file Topology file to read
  # @return [void]
  def make(target_file)
    maker = L1InterfaceDescriptionMaker.new(target_file)
    maker.make(options[:output] || '')
  end

  private

  # @param [Object] data Data to print
  # @return [void]
  def print_data(data)
    puts options[:format] == 'yaml' ? YAML.dump(data) : JSON.pretty_generate(data)
  end
end

# start CLI tool
L1InterfaceDescriptionOperator.start(ARGV)
