# frozen_string_literal: true

require 'fileutils'
require 'grape'
require 'httpclient'
require 'json'
require 'netomox'
require_relative 'model_defs/topology_builder/networks'

# Directories
QUERIES_DIR = ENV.fetch('MDDO_MODELS_DIR', 'models')
TOPOLOGIES_DIR = ENV.fetch('MDDO_NETOVIZ_MODEL_DIR', 'netoviz_model')

# Netomox REST API definition
class NetomoxRestApi < Grape::API
  format :json

  helpers do
    # @param [String] file_path File path to read
    # @return [Hash,Array]
    def read_json_file(file_path)
      error!(:not_found, 404) unless File.exist?(file_path)
      JSON.parse(File.read(file_path))
    end

    # @param [String] file_path File path to save
    # @param [void]
    def save_json_file(file_path, data)
      JSON.dump(data, File.open(file_path, 'w'))
    end

    # @param [String] network Network name
    # @param [String] snapshot Snapshot name
    # @return [Netomox::Topology::Networks] Networks instance
    def read_topology_file(network, snapshot)
      topology_file = File.join(TOPOLOGIES_DIR, network, snapshot, 'topology.json')
      Netomox::Topology::Networks.new(read_json_file(topology_file))
    end
  end

  # rubocop:disable Metrics/BlockLength
  namespace 'topologies' do
    desc 'Post (register) netoviz index'
    params do
      requires :index_data, type: Array, desc: 'List of topology'
    end
    post 'index' do
      index_file = File.join(TOPOLOGIES_DIR, '_index.json')
      save_json_file(index_file, params[:index_data])
      {
        method: 'POST',
        path: '/topologies/index'
      }
    end

    params do
      requires :network, type: String, desc: 'Network name'
    end

    resource ':network' do
      desc 'Get topology diff'
      params do
        requires :src_ss, type: String, desc: 'Source snapshot name'
        requires :dst_ss, type: String, desc: 'Destination snapshot name'
      end
      get 'snapshot_diff/:src_ss/:dst_ss' do
        # send diff data between src_ss and dst_ss
        network = params[:network]
        src_ss = params[:src_ss]
        dst_ss = params[:dst_ss]

        src_nws = read_topology_file(network, src_ss)
        dst_nws = read_topology_file(network, dst_ss)
        diff_nws = src_nws.diff(dst_nws)
        topology_data = diff_nws.to_data
        {
          method: 'GET',
          path: "/topologies/snapshot_diff/#{src_ss}/#{dst_ss}",
          topology_data:
        }
      end

      params do
        requires :snapshot, type: String, desc: 'Snapshot name'
      end

      resource ':snapshot' do
        desc 'Post (register) topology data'
        params do
          optional :topology_data, type: Hash, desc: 'RFC8345 topology data'
        end
        post do
          network = params[:network]
          snapshot = params[:snapshot]

          query_snapshot_dir = File.join(QUERIES_DIR, network, snapshot)
          topology_snapshot_dir = File.join(TOPOLOGIES_DIR, network, snapshot)
          topology_data = if params.key?(:topology_data)
                            params[:topology_data]
                          else
                            TopologyBuilder.generate_data(query_snapshot_dir)
                          end

          # generate(overwrite) topology data
          topology_file = File.join(topology_snapshot_dir, 'topology.json')
          save_json_file(topology_file, topology_data)
          {
            method: 'POST',
            path: "/topologies/#{network}/#{snapshot}",
            message: 'Generate/Overwrite topology.json',
            topology_data:
          }
        end

        desc 'Get topology data'
        get 'topology' do
          network = params[:network]
          snapshot = params[:snapshot]

          topology_snapshot_dir = File.join(TOPOLOGIES_DIR, network, snapshot)
          topology_file = File.join(topology_snapshot_dir, 'topology.json')
          topology_data = read_json_file(topology_file)
          {
            method: 'GET',
            path: "/topologies/#{network}/#{snapshot}",
            topology_data:
          }
        end
      end
    end
    # rubocop:enable Metrics/BlockLength
  end
end
