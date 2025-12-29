# frozen_string_literal: true

require 'grape'
require 'lib/api/rest_api_base'

module NetomoxExp
  module ApiRoute
    # namespace /converted_topology
    class ConvertedTopology < RestApiBase
      resource 'converted_topology' do
        desc 'Get namespace-convert-table to get converted topology'
        get do
          network, snapshot = %i[network snapshot].map { |key| params[key] }
          # NOTE: Not only conversion from original to emulated, but also from emulated to original is required.
          #   When convert from emulated to original, it needs namespace-convert-table generated from original.
          #   It means that topology conversion operation is stateful.
          #   Currently, netomox-exp does not keep these operation state.
          #   Simply, it re-use (reload) convert table kept in topologies/<network>/ns_convert_table.json.
          #   which generated from original_asis in step1 of copy_to_emulated_env demo.
          ns_converter = ns_converter_wo_topology(network)
          ns_converter.load_origin_topology(read_topology_file(network, snapshot))

          # response
          ns_converter.convert
        end
      end
    end
  end
end
