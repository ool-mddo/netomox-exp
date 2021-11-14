# frozen_string_literal: true

require 'optparse'
require_relative 'mddo_trial/networks'

opts = ARGV.getopts('d', 'debug:')
if opts['d']
  puts 'OOL-MDDO PJ Trial(2) L2 sample5'
  exit 0
end

target_config = 'l2_sample5'

if opts['debug']
  generate_json(target_config, layer: opts['debug'], debug: true)
  exit 0
end

puts generate_json(target_config)
