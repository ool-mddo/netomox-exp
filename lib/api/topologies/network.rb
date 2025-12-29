# frozen_string_literal: true

require 'fileutils'
require 'grape'
require 'lib/api/rest_api_base'
require_relative 'network/ns_convert_table'
require_relative 'network/snapshot'

module NetomoxExp
  module ApiRoute
    # namespace /network
    class Network < RestApiBase
      params do
        requires :network, type: String, desc: 'Network name'
      end
      resource ':network' do
        desc 'Delete topologies data'
        delete do
          network_dir = File.join(TOPOLOGIES_DIR, params[:network])
          FileUtils.rm_rf(network_dir)

          # response
          ''
        end

        desc 'Get snapshot list'
        params do
          optional :prefix, type: String, desc: 'Prefix of snapshot name'
        end
        get 'snapshots' do
          network_dir = File.join(TOPOLOGIES_DIR, params[:network])
          if params[:prefix].nil?
            Dir.children(network_dir)
               .select { |entry| File.directory?(File.join(network_dir, entry)) }
          else
            Dir.children(network_dir)
               .select { |entry| File.directory?(File.join(network_dir, entry)) }
               .select { |entry| entry.start_with?(params[:prefix]) }
          end
        end

        mount ApiRoute::NsConvertTable
        mount ApiRoute::Snapshot
      end
    end
  end
end
