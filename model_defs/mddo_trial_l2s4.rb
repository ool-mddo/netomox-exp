# frozen_string_literal: true

require 'optparse'
require_relative 'mddo_trial/networks'

opts = ARGV.getopts('d', 'debug:')
if opts['d']
  puts 'OOL-MDDO PJ Trial(2) L2 sample4'
  exit 0
end

target_config = 'sample4'
if opts['debug']
  dump(target_config, opts['debug'])
  exit 0
end

puts generate_json(target_config)
