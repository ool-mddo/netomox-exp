# frozen_string_literal: true

require 'fileutils'
require 'grape'
require 'json'
require 'netomox'
require_relative 'model_defs/topology_builder/networks'

# Directories
QUERIES_DIR = ENV.fetch('MDDO_QUERIES_DIR', 'queries')
TOPOLOGIES_DIR = ENV.fetch('MDDO_TOPOLOGIES_DIR', 'topologies')
MODEL_DEFS_DIR = './model_defs'

# rubocop:disable Metrics/ClassLength

# Netomox REST API definition
class NetomoxRestApi < Grape::API
  format :json

  helpers do
    def logger
      # reuse topology-builder logger
      TopologyBuilder.logger
    end

    # @param [String] file_path File path to read
    # @return [Hash,Array]
    def read_json_file(file_path)
      error!(:not_found, 404) unless File.exist?(file_path)
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
      desc 'Delete topologies data'
      delete do
        network_dir = File.join(TOPOLOGIES_DIR, params[:network])
        FileUtils.rm_rf(network_dir)
        {
          method: 'DELETE',
          path: "/topologies/#{params[:network]}",
          dir: network_dir
        }
      end

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
        post 'topology' do
          network = params[:network]
          snapshot = params[:snapshot]
          api_path = "/topologies/#{network}/#{snapshot}"
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

          {
            method: 'POST',
            path: "/topologies/#{network}/#{snapshot}/topology",
            topology_data:
          }
        end

        desc 'Get topology data'
        get 'topology' do
          network = params[:network]
          snapshot = params[:snapshot]

          topology_file = File.join(TOPOLOGIES_DIR, network, snapshot, 'topology.json')
          topology_data = read_json_file(topology_file)
          {
            method: 'GET',
            path: "/topologies/#{network}/#{snapshot}/topology",
            topology_data:
          }
        end
      end
    end
    # rubocop:enable Metrics/BlockLength
  end
end
# rubocop:enable Metrics/ClassLength
