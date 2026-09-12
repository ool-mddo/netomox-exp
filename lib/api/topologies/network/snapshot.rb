# frozen_string_literal: true

require 'fileutils'
require 'lib/api/rest_api_base'
require_relative 'snapshot/converted_topology'
require_relative 'snapshot/topology/layer'
require_relative 'snapshot/topology'

module NetomoxExp
  module ApiRoute
    # namespace /snapshot
    class Snapshot < RestApiBase
      params do
        requires :snapshot, type: String, desc: 'Snapshot name'
      end
      resource ':snapshot' do
        desc 'Delete snapshot data'
        delete do
          snapshot_dir = File.join(TOPOLOGIES_DIR, params[:network], params[:snapshot])
          FileUtils.rm_rf(snapshot_dir)
          ''
        end

        mount ApiRoute::ConvertedTopology
        mount ApiRoute::Topology
      end
    end
  end
end
