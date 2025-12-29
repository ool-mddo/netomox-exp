# frozen_string_literal: true

require 'grape'
require_relative 'rest_api_base'
require_relative 'topologies/network'

module NetomoxExp
  module ApiRoute
    # namespace /topologies
    class Topologies < RestApiBase
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

        desc 'Fetch netoviz index'
        get 'index' do
          index_file = File.join(TOPOLOGIES_DIR, '_index.json')
          # response
          read_json_file(index_file)
        end

        mount ApiRoute::Network
      end
    end
  end
end
