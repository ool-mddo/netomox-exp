# frozen_string_literal: true

require 'netomox'
require 'optparse'
require 'json'
require 'yaml'
require 'csv'
require_relative 'external_as_topology/bgp_as_data_builder'

USECASE_DIR = ENV['USECASE_DIR'] || "#{__dir__}/../../../../usecases" # playground/usecases
TOPOLOGY_DIR = ENV['TOPOLOGY_DIR'] || "#{__dir__}/../../../../topologies" # playground/topologies

# helpers

def read_json_file(file_path)
  JSON.parse(File.read(file_path))
end

def read_yaml_file(file_path)
  YAML.load_file(file_path)
end

def read_csv_file(file_path)
  csv_data = CSV.read(file_path, headers: true)
  csv_data.map(&:to_h)
end

def read_flow_data(usecase, network, flow_file)
  flow_file_path = File.join(USECASE_DIR, usecase, network, 'flows', "#{flow_file}.csv")
  read_csv_file(flow_file_path)
end

def read_params(usecase, network)
  param_file_path = File.join(USECASE_DIR, usecase, network, 'params.yaml')
  read_yaml_file(param_file_path)
end

def read_topology_object(network, snapshot)
  topology_file_path = File.join(TOPOLOGY_DIR, network, snapshot, 'topology.json')
  topology_data = read_json_file(topology_file_path)
  Netomox::Topology::Networks.new(topology_data)
end

# main

begin
  # option definitions

  options = {}
  opt_parser = OptionParser.new do |opts|
    opts.banner = "Usage: #{$PROGRAM_NAME} [options]"
    opts.on('-n', '--network NETWORK', 'Network (required)') do |network|
      options[:network] = network
    end
    opts.on('-s', '--snapshot SNAPSHOT', 'Snapshot (required)') do |snapshot|
      options[:snapshot] = snapshot
    end
    opts.on('-u', '--usecase USECASE', 'Usecase (required)') do |usecase|
      options[:usecase] = usecase
    end
  end

  opt_parser.parse!

  %i[network snapshot usecase].each do |key|
    next unless options[key].nil?

    puts "Error: #{key} is required"
    puts opt_parser
    exit 1
  end

  # debug
  network, snapshot, usecase = %i[network snapshot usecase].map { |key| options[key]}
  warn "Network: #{network}"
  warn "Snapshot: #{snapshot}"
  warn "Usecase: #{usecase}"

  # read files
  usecase_params = read_params(usecase, network)
  usecase_flows = read_flow_data(usecase, network, 'event')
  int_as_topology = read_topology_object(network, snapshot)

  # build ext-as topology data
  builder = NetomoxExp::UsecaseDeliverer::BgpAsDataBuilder.new(usecase, usecase_params, usecase_flows, int_as_topology)
  puts JSON.generate(builder.build_topology)
rescue OptionParser::InvalidOption, OptionParser::MissingArgument => e
  warn e.message
  exit 1
end
