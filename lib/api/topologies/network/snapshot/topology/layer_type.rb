# frozen_string_literal: true

require 'grape'
require_relative 'layer_type/layers_objects'

module NetomoxExp
  module ApiRoute
    # namespace /layers
    class LayerType < Grape::API
      params do
        requires 'layer_type', type: Symbol, values: %i[layer1 layer2 layer3 ospf], desc: 'Type of network layer'
      end
      resource 'layer_type_:layer_type' do
        mount ApiRoute::LayersObjects
      end
    end
  end
end
