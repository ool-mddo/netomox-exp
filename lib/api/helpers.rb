# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'netomox'
require 'lib/convert_namespace/namespace_converter'

module NetomoxExp
  # helpers for NetomoxRestApi
  module Helpers
    # @param [String] file_path File path to read
    # @return [Object]
    def read_json_file(file_path)
      error!("Not found: topology file: #{file_path}", 404) unless File.exist?(file_path)

      JSON.parse(File.read(file_path))
    end

    # @param [String] file_path File path to save
    # @param [void]
    def save_json_file(file_path, data)
      logger.warn "[save_json_file] path=#{file_path}"
      FileUtils.mkdir_p(File.dirname(file_path))
      File.open(file_path, 'w') { |file| JSON.dump(data, file) }
    end

    # @param [String] network Network name
    # @param [String] snapshot Snapshot name
    # @return [Object] Networks data
    def read_topology_file(network, snapshot)
      topology_file = File.join(TOPOLOGIES_DIR, network, snapshot, 'topology.json')
      read_json_file(topology_file)
    end

    # @param [String] network Network name
    # @param [String] snapshot Snapshot name
    # @return [Netomox::Topology::Networks] topology instance
    def read_topology_instance(network, snapshot)
      topology_data = read_topology_file(network, snapshot)
      Netomox::Topology::Networks.new(topology_data)
    end

    # @param [String] network Network name
    # @return [String] file path
    def ns_convert_table_file(network)
      File.join(TOPOLOGIES_DIR, network, 'ns_convert_table.json')
    end

    # @param [String] network Network name
    # @return [void]
    def save_ns_convert_table(network, data)
      save_json_file(ns_convert_table_file(network), data)
    end

    # @param [String] network Network name
    # @return [Hash] convert_table
    def read_ns_convert_table(network)
      read_json_file(ns_convert_table_file(network))
    end

    # @param [String] network Network name
    # @return [NamespaceConverter] Namespace converter without topology data
    def ns_converter_wo_topology(network)
      ns_converter = NamespaceConverter.new
      ns_converter.reload_convert_table(read_ns_convert_table(network))
      ns_converter
    end
  end
end
