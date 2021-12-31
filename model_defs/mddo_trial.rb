# frozen_string_literal: true

require 'optparse'
require_relative 'mddo_trial/networks'

opts = ARGV.getopts('i:', 'debug:')

unless opts['i']
  warn 'Specify input data directory path with -i'
  exit 1
end

target_data_dir = opts['i']

if opts['debug']
  puts generate_json(target_data_dir, layer: opts['debug'], debug: true)
  exit 0
end

puts generate_json(target_data_dir)
