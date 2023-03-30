# frozen_string_literal: true

require 'fileutils'
require 'grape'
require 'lib/convert_namespace/layer_filter'
require 'model_defs/topology_builder/networks'
require_relative 'topology/layer'

module NetomoxExp
  module ApiRoute
    # namespace /topology
    class Topology < Grape::API
      desc 'Post (register) topology data'
      # rubocop:disable Metrics/BlockLength
      resource 'topology' do
        params do
          optional :topology_data, type: Hash, desc: 'RFC8345 topology data'
        end
        post do
          network, snapshot = %i[network snapshot].map { |key| params[key] }
          api_path = "/topologies/#{network}/#{snapshot}/topology"

          topology_data =
            if params.key?(:topology_data)
              logger.debug("[post #{api_path}] posted topology data")
              params[:topology_data]
            else
              query_snapshot_dir = File.join(QUERIES_DIR, network, snapshot)
              logger.debug("[post #{api_path}] query_snapshot_dir: #{query_snapshot_dir}")
              TopologyBuilder.generate_data(query_snapshot_dir)
            end

          # generate(overwrite) topology data
          topology_dir = File.join(TOPOLOGIES_DIR, network, snapshot)
          topology_file = File.join(topology_dir, 'topology.json')
          save_json_file(topology_file, topology_data)

          # copy layout file if found
          layout_file = File.join(MODEL_DEFS_DIR, network, snapshot, 'layout.json')
          FileUtils.cp(layout_file, File.join(topology_dir, 'layout.json')) if File.exist?(layout_file)
        end

        desc 'Get topology data'
        get do
          network, snapshot = %i[network snapshot].map { |key| params[key] }
          # response
          read_topology_file(network, snapshot)
        end

        desc 'Get topology data (L3+ layers)'
        get 'upper_layer3' do
          network, snapshot = %i[network snapshot].map { |key| params[key] }
          layer_filter = LayerFilter.new(read_topology_file(network, snapshot))
          # response
          layer_filter.filter
        end

        mount ApiRoute::Layer
      end
      # rubocop:enable Metrics/BlockLength
    end
  end
end
