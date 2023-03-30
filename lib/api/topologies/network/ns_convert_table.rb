# frozen_string_literal: true

require 'grape'
require 'fileutils'
require 'lib/convert_namespace/namespace_converter'

module NetomoxExp
  module ApiRoute
    # namespace /ns_convert_table
    class NsConvertTable < Grape::API
      # rubocop:disable Metrics/BlockLength
      resource 'ns_convert_table' do
        desc 'Post convert_table'
        params do
          optional :origin_snapshot, type: String, desc: 'Origin snapshot name'
          optional :convert_table, type: Hash, desc: 'Convert table'
          mutually_exclusive :origin_snapshot, :convert_table, message: 'are exclusive cannot pass both params'
        end
        post do
          network = params[:network]
          ns_converter = NamespaceConverter.new
          if params.key?(:origin_snapshot)
            snapshot = params[:origin_snapshot]
            logger.info "Initialize namespace convert table with snapshot: #{network}/#{snapshot}"
            ns_converter.make_convert_table(read_topology_file(network, snapshot))
          else
            logger.info "Update namespace convert table of network: #{network}"
            ns_converter.reload_convert_table(params[:convert_table])
          end
          save_ns_convert_table(network, ns_converter.convert_table)
          # response
          {}
        end

        desc 'Get convert_table'
        get do
          # response
          read_ns_convert_table(params[:network])
        end

        desc 'Delete convert_table'
        delete do
          FileUtils.rm_f(ns_convert_table_file(params[:network]))
          # response
          ''
        end

        desc 'Convert hostname'
        params do
          requires :host_name, type: String, desc: 'Host name to convert'
          optional :if_name, type: String, desc: 'Interface name to convert'
        end
        post 'query' do
          network, host_name = %i[network host_name].map { |key| params[key] }
          ns_converter = ns_converter_wo_topology(network)
          begin
            resp = { origin_host: host_name, target_host: ns_converter.node_name_table.convert(host_name) }
            if params.key?(:if_name)
              if_name = params[:if_name]
              resp[:origin_if] = if_name
              resp[:target_if] = ns_converter.tp_name_table.convert(host_name, if_name)
            end
            # response
            resp
          rescue StandardError
            error!("#{params} not found in convert table", 404)
          end
        end
      end
      # rubocop:enable Metrics/BlockLength
    end
  end
end
