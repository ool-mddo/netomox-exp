# frozen_string_literal: true

require 'lib/api/rest_api_base'
require 'lib/api/helpers_netoviz2'
require 'lib/netoviz2/summary_builder'
require 'lib/netoviz2/layer_builder'
require 'lib/netoviz2/supports_builder'
require 'lib/netoviz2/attributes_builder'

module NetomoxExp
  module ApiRoute
    # namespace /netoviz2 : data for netoviz2 (see docs/netoviz2_data_format.md in playground)
    class Netoviz2Api < RestApiBase
      helpers Netoviz2ApiHelpers

      resource 'netoviz2' do
        desc 'Summary of the topology (layers, flags, warnings, etag)'
        get 'summary' do
          netoviz2_respond do |network, snapshot, etag, model|
            Netoviz2::SummaryBuilder.new(model, network:, snapshot:, etag:).build
          end
        end

        desc 'Structure of a layer (nodes, term-points, links; without attributes)'
        get 'layers/:layer', requirements: { layer: %r{[^/]+} } do
          netoviz2_respond do |_network, _snapshot, etag, model|
            netoviz2_layer_data(model, params[:layer]).merge(etag:)
          end
        end

        desc 'Supports between objects (all layers)'
        get 'supports' do
          netoviz2_respond { |_nw, _ss, etag, model| Netoviz2::SupportsBuilder.new(model).build.merge(etag:) }
        end

        # POST (but read only) to avoid the limit of URL length. Conditional request (304) is not supported
        desc 'Attributes and diff details of the specified objects'
        params { optional :ids, desc: 'Object IDs (array of string)' }
        post 'attributes' do
          ids = netoviz2_attribute_ids(params[:ids])
          status 200
          netoviz2_respond(conditional: false) do |_nw, _ss, etag, model|
            Netoviz2::AttributesBuilder.new(model).build(ids).merge(etag:)
          end
        end
      end
    end
  end
end
