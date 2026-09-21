# frozen_string_literal: true

require 'fileutils'
require 'lib/api/rest_api_base'
require 'lib/convert_namespace/namespace_converter'

module NetomoxExp
  module ApiRoute
    # namespace /ns_convert_table
    class NsConvertTable < RestApiBase
      helpers do
        # @param [String] usecase_name Usecase name
        # @param [String] network_name Network name
        # @return [Hash] Usecase parameters
        def read_usecase_params(usecase_name, network_name)
          return {} unless usecase_name

          read_params(usecase_name, network_name)
        end
      end

      # rubocop:disable-next Metrics/BlockLength
      resource 'ns_convert_table' do
        desc 'Post convert_table'
        params do
          optional :convert_table, type: Hash, desc: 'Convert table (manual override)'
          optional :usecase, type: String, desc: 'Usecase name', default: nil
        end
        post do
          network, snapshot = %i[network snapshot].map { |key| params[key] }
          ns_converter = ConvertNamespace::NamespaceConverter.new

          if params.key?(:convert_table)
            logger.info "Update namespace convert table of network: #{network}/#{snapshot}"
            ns_converter.reload(params[:convert_table])
          else
            logger.info "Initialize namespace convert table with snapshot: #{network}/#{snapshot}"
            topology_data = read_topology_file(network, snapshot)
            usecase_params = read_usecase_params(params[:usecase], network)
            ns_converter.load_origin_topology(topology_data, usecase_params)
          end
          save_ns_convert_table(network, snapshot, ns_converter.to_hash)

          # response
          {}
        end

        desc 'Get convert_table'
        get do
          network, snapshot = %i[network snapshot].map { |key| params[key] }

          # response
          read_ns_convert_table(network, snapshot)
        end

        desc 'Delete convert_table'
        delete do
          network, snapshot = %i[network snapshot].map { |key| params[key] }
          FileUtils.rm_f(ns_convert_table_file(network, snapshot))

          # response
          ''
        end

        desc 'Convert hostname'
        params do
          requires :host_name, type: String, desc: 'Host name to convert'
          optional :if_name, type: String, desc: 'Interface name to convert'
        end
        post 'query' do
          network, snapshot, host_name = %i[network snapshot host_name].map { |key| params[key] }
          ns_converter = ns_converter_wo_topology(network, snapshot)
          begin
            resp = { origin_host: host_name, target_host: ns_converter.node_name.convert(host_name) }
            if params.key?(:if_name)
              if_name = params[:if_name]
              resp[:origin_if] = if_name
              resp[:target_if] = ns_converter.tp_name.convert(host_name, if_name)
            end

            # response
            resp
          rescue StandardError
            error!("#{params} not found in convert table", 404)
          end
        end
      end
    end
  end
end
