# frozen_string_literal: true

require 'lib/api/rest_api_base'
require_relative 'layer/config_params'
require_relative 'layer/convert_layer_topology'
require_relative 'layer/layer_objects'
require_relative 'layer/verify_layer'

module NetomoxExp
  module ApiRoute
    # namespace /layer
    class Layer < RestApiBase
      params do
        requires :layer, type: String, desc: 'Network layer'
      end
      resource ':layer' do
        mount ApiRoute::ConfigParams
        mount ApiRoute::ConvertLayerTopology
        mount ApiRoute::LayerObjects
        mount ApiRoute::VerifyLayer
      end
    end
  end
end
