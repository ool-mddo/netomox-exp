# frozen_string_literal: true

require 'fileutils'
require 'grape'
require_relative 'network/ns_convert_table'
require_relative 'network/snapshot'

module NetomoxExp
  module ApiRoute
    # namespace /network
    class Network < Grape::API
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

        mount ApiRoute::NsConvertTable
        mount ApiRoute::Snapshot
      end
    end
  end
end
