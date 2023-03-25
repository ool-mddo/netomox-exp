# frozen_string_literal: true

require 'fileutils'
require 'grape'
require 'json'
require 'netomox'
require_relative 'model_defs/topology_builder/networks'
require_relative 'lib/convert_namespace/namespace_converter'
require_relative 'lib/convert_namespace/layer_filter'
require_relative 'lib/convert_topology/batfish_converter'
require_relative 'lib/convert_topology/containerlab_converter'

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
      # reply
      {}
    end

    params do
      requires :network, type: String, desc: 'Network name'
    end

    resource ':network' do
      desc 'Delete topologies data'
      delete do
        network_dir = File.join(TOPOLOGIES_DIR, params[:network])
        FileUtils.rm_rf(network_dir)
      end

      params do
        requires :snapshot, type: String, desc: 'Snapshot name'
      end

      resource ':snapshot' do
        desc 'Post (register) topology data'
        resource 'topology' do
          params do
            optional :topology_data, type: Hash, desc: 'RFC8345 topology data'
          end
          post do
            network = params[:network]
            snapshot = params[:snapshot]
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

            # reply
            topology_data
          end

          desc 'Get topology data'
          get do
            # reply
            read_topology_file(params[:network], params[:snapshot])
          end

          desc 'Get topology data (L3+ layers)'
          get 'upper_layer3' do
            layer_filter = LayerFilter.new(read_topology_file(params[:network], params[:snapshot]))
            # reply
            layer_filter.filter
          end

          params do
            requires :layer, type: String, desc: 'Network layer'
          end
          resource ':layer' do
            desc 'convert layer data to batfish layer1_topology.json'
            get 'batfish_layer1_topology' do
              topology_data = read_topology_file(params[:network], params[:snapshot])
              converter = BatfishConverter.new(topology_data, params[:layer])
              converter.convert
            end

            desc 'convert layer data to containerl-lab topology json'
            params do
              optional :env_name, type: String, desc: 'Environment name (for container-lab)', default: 'emulated'
            end
            get 'containerlab_topology' do
              topology_data = read_topology_file(params[:network], params[:snapshot])
              opts = { env_name: params[:env_name] }
              converter = ContainerLabConverter.new(topology_data, params[:layer], opts)
              converter.convert
            end
          end
        end

        resource 'converted_topology' do
          desc 'Post namespace-convert-table to get converted topology'
          params do
            optional :convert_table, type: Hash, desc: 'Namespace convert table'
          end
          post do
            converter = NamespaceConverter.new(read_topology_file(params[:network], params[:snapshot]))
            if params.key?(:convert_table)
              converter.reload_convert_table(params[:convert_table])
            else
              converter.make_convert_table
            end
            # reply
            {
              convert_table: converter.convert_table,
              converted_topology_data: converter.convert
            }
          end
        end
      end
    end
    # rubocop:enable Metrics/BlockLength
  end
end
# rubocop:enable Metrics/ClassLength
