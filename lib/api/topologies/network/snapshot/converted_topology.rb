# frozen_string_literal: true

require 'lib/api/rest_api_base'

module NetomoxExp
  module ApiRoute
    # namespace /converted_topology
    class ConvertedTopology < RestApiBase
      resource 'converted_topology' do
        desc 'Get namespace-convert-table to get converted topology'
        get do
          network, snapshot = %i[network snapshot].map { |key| params[key] }
          ns_converter = ns_converter_wo_topology(network, snapshot)
          ns_converter.load_origin_topology(read_topology_file(network, snapshot))

          # response
          ns_converter.convert
        end
      end
    end
  end
end
