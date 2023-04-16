# frozen_string_literal: true

require 'grape'
require_relative 'topologies/network'

module NetomoxExp
  module ApiRoute
    # namespace /topologies
    class Topologies < Grape::API
      namespace 'topologies' do
        desc 'Post (register) netoviz index'
        params do
          requires :index_data, type: Array, desc: 'List of topology'
        end
        post 'index' do
          index_file = File.join(TOPOLOGIES_DIR, '_index.json')
          save_json_file(index_file, params[:index_data])
          # response
          {}
        end

        mount ApiRoute::Network
      end
    end
  end
end
