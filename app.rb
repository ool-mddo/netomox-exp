# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'netomox'
require_relative 'lib/rest_api_base'
require_relative 'model_defs/topology_builder/networks'
require_relative 'lib/convert_namespace/namespace_converter'
require_relative 'lib/convert_namespace/layer_filter'
require_relative 'lib/convert_topology/batfish_converter'
require_relative 'lib/convert_topology/containerlab_converter'

# Directory to save batfish query answers
QUERIES_DIR = ENV.fetch('MDDO_QUERIES_DIR', 'queries')
# Directory to save topology json from batfish query answers
TOPOLOGIES_DIR = ENV.fetch('MDDO_TOPOLOGIES_DIR', 'topologies')
# (temporary) layout file directory
MODEL_DEFS_DIR = './model_defs'

module NetomoxExp
  # rubocop:disable Metrics/ClassLength

  # Netomox REST API definition
  class NetomoxRestApi < RestApiBase
    # rubocop:disable Metrics/BlockLength
    helpers do
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
    end
    # rubocop:enable Metrics/BlockLength

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

        resource 'ns_convert_table' do
          desc 'Post convert_table'
          params do
            optional :origin_snapshot, type: String, desc: 'Origin snapshot name'
            optional :convert_table, type: Hash, desc: 'Convert table'
            mutually_exclusive :origin_snapshot, :convert_table, message: 'are exclusive cannot pass both params'
          end
          post do
            network = params[:network]
            converter = NamespaceConverter.new
            if params.key?(:origin_snapshot)
              snapshot = params[:origin_snapshot]
              logger.info "Initialize namespace convert table with snapshot: #{network}/#{snapshot}"
              converter.make_convert_table(read_topology_file(network, snapshot))
            else
              logger.info "Update namespace convert table of network: #{network}"
              converter.reload_convert_table(params[:convert_table])
            end
            save_ns_convert_table(network, converter.convert_table)
          end

          desc 'Get convert_table'
          get do
            # reply
            read_ns_convert_table(params[:network])
          end

          desc 'Delete convert_table'
          delete do
            FileUtils.rm_f(ns_convert_table_file(params[:network]))
          end

          desc 'Convert hostname'
          params do
            requires :host_name, type: String, desc: 'Host name to convert'
            optional :if_name, type: String, desc: 'Interface name to convert'
          end
          post 'query' do
            converter = NamespaceConverter.new
            converter.reload_convert_table(read_ns_convert_table(params[:network]))
            begin
              resp = { origin_host: params[:host_name], target_host: converter.convert_node_name(params[:host_name]) }
              if params.key?(:if_name)
                resp[:origin_if] = params[:if_name]
                resp[:target_if] = converter.convert_tp_name(params[:host_name], params[:if_name])
              end
              # reply
              resp
            rescue StandardError
              error!("#{params} not found in convert table", 404)
            end
          end
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

              desc 'Get nodes in the layer'
              params do
                optional :node_type, type: String, desc: 'Node type'
              end
              get 'nodes' do
                network, snapshot, layer = %i[network snapshot layer].map { |key| params[key] }

                nws = read_topology_instance(network, snapshot)
                nw = nws.find_network(layer)
                error!("#{network}/#{snapshot}/#{layer} not found", 404) if nw.nil?

                nw.nodes.map(&:name)
              end
            end
          end

          resource 'converted_topology' do
            desc 'Get namespace-convert-table to get converted topology'
            get do
              network = params[:network]
              snapshot = params[:snapshot]

              converter = NamespaceConverter.new
              converter.load_origin_topology(read_topology_file(network, snapshot))
              converter.reload_convert_table(read_ns_convert_table(network))
              # reply
              converter.convert
            end
          end
        end
      end
      # rubocop:enable Metrics/BlockLength
    end
  end
  # rubocop:enable Metrics/ClassLength
end
