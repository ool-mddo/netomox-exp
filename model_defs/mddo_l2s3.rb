# frozen_string_literal: true

require 'optparse'
require_relative 'mddo_trial/networks'

opts = ARGV.getopts('d', 'debug:')
if opts['d']
  puts 'OOL-MDDO PJ Trial(2) L2 sample3'
  exit 0
end

target_data_dir = 'models/batfish-test-topology/l2/sample3'

if opts['debug']
  generate_json(target_data_dir, layer: opts['debug'], debug: true)
  exit 0
end

puts generate_json(target_data_dir)
