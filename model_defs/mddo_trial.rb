# frozen_string_literal: true

require 'json'
require 'optparse'
require_relative 'topology_builder/networks'

opts = ARGV.getopts('i:', 'debug:')

unless opts['i']
  warn 'Specify input data directory path with -i'
  exit 1
end

target_data_dir = opts['i']

# @param [Hash] topology_data RFC8345 topology data
# @return [String] json string of the topology_data
def to_json(topology_data)
  JSON.pretty_generate(topology_data)
end

if opts['debug']
  puts to_json(TopologyBuilder.generate_data(target_data_dir, layer: opts['debug'], debug: true))
  exit 0
end

puts to_json(TopologyBuilder.generate_data(target_data_dir))
