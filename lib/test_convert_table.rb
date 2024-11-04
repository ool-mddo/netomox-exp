# frozen_string_literal: true

require 'json'
require 'optparse'
require_relative 'convert_namespace/namespace_converter'

module NetomoxExp
  # namespace for testing scripts
  module TestTools
    module_function

    # rubocop:disable Metrics/MethodLength
    def main
      opts = ARGV.getopts('t:')

      unless opts['t']
        warn 'Specify topology data with -t'
        exit 1
      end

      converter = NetomoxExp::ConvertNamespace::NamespaceConverter.new

      # load from files
      topology_file = opts['t']
      topology_data = JSON.parse(File.read(topology_file))
      converter.load_origin_topology(topology_data)

      # ns_convert_table = JSON.parse(File.read('ns_convert_table.json'))
      # converter.reload(ns_convert_table)

      # convert table
      puts JSON.pretty_generate(converter.to_hash)

      # converted config
      puts JSON.pretty_generate(converter.convert)
    end
    # rubocop:enable Metrics/MethodLength
  end
end

NetomoxExp::TestTools.main
