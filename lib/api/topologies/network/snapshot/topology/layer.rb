# frozen_string_literal: true

require 'grape'
require_relative 'layer/config_params'
require_relative 'layer/convert_layer_topology'
require_relative 'layer/layer_objects'
require_relative 'layer/static_verification'

module NetomoxExp
  module ApiRoute
    # namespace /layer
    class Layer < Grape::API
      params do
        requires :layer, type: String, desc: 'Network layer'
      end
      resource ':layer' do
        mount ApiRoute::ConfigParams
        mount ApiRoute::ConvertLayerTopology
        mount ApiRoute::LayerObjects
        mount ApiRoute::StaticVerification
      end
    end
  end
end
