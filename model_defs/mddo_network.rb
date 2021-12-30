# frozen_string_literal: true

require 'optparse'
require_relative 'mddo_trial/networks'

opts = ARGV.getopts('d', 'debug:')
if opts['d']
  puts 'OOL-MDDO PJ Trial Target Network'
  exit 0
end

target_data_dir = 'models/pushed_configs/mddo_network'

if opts['debug']
  puts generate_json(target_data_dir, layer: opts['debug'], debug: true)
  exit 0
end

puts generate_json(target_data_dir)
