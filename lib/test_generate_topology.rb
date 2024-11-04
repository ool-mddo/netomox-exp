# frozen_string_literal: true

require 'json'
require 'optparse'
require_relative 'netomox_exp'
require_relative 'topology_builder/topology_builder'

module NetomoxExp
  # namespace for testing scripts
  module TestTools
    module_function

    # @param [Hash] topology_data RFC8345 topology data
    # @return [String] json string of the topology_data
    def to_json(topology_data)
      JSON.pretty_generate(topology_data)
    end

    # rubocop:disable Metrics/MethodLength
    def main
      opts = ARGV.getopts('i:', 'debug:')

      unless opts['i']
        warn 'Specify input data directory path with -i'
        exit 1
      end

      target_data_dir = opts['i']

      if opts['debug']
        puts to_json(NetomoxExp::TopologyBuilder.generate_data(target_data_dir, layer: opts['debug'], debug: true))
      else
        puts to_json(NetomoxExp::TopologyBuilder.generate_data(target_data_dir))
      end
    end
    # rubocop:enable Metrics/MethodLength
  end
end

NetomoxExp::TestTools.main
