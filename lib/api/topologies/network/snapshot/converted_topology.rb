# frozen_string_literal: true

require 'grape'

module NetomoxExp
  module ApiRoute
    # namespace /converted_topology
    class ConvertedTopology < Grape::API
      resource 'converted_topology' do
        desc 'Get namespace-convert-table to get converted topology'
        get do
          network, snapshot = %i[network snapshot].map { |key| params[key] }
          ns_converter = ns_converter_wo_topology(network)
          ns_converter.load_origin_topology(read_topology_file(network, snapshot))
          # response
          ns_converter.convert
        end
      end
    end
  end
end
