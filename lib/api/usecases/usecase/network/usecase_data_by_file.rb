# frozen_string_literal: true

require 'grape'
require 'lib/api/rest_api_base'
require 'lib/usecase_deliverer/layer3_preallocated_resource_builder'

module NetomoxExp
  module ApiRoute
    # usecase parameter handling
    class UsecaseDataByFile < RestApiBase
      desc 'Get flow data (csv -> json)'
      get 'flows/:file_name' do
        usecase, network, flow_file = %i[usecase network file_name].map { |key| params[key] }
        read_flow_data(usecase, network, flow_file)
      end

      desc 'Get layer3 preallocated (empty) resources'
      get 'params/l3_preallocated_resources' do
        usecase, network = %i[usecase network].map { |key| params[key] }
        usecase_params = read_params(usecase, network)
        unless usecase_params.key?('l3_preallocated_resources')
          error!('ERROR: l3_preallocated_resources is not defined in usecase params', 400)
        end

        builder = UsecaseDeliverer::Layer3PreallocatedResourceBuilder.new(usecase, usecase_params)

        # response
        builder.build_topology
      end

      desc 'Get usecase params (yaml -> json)'
      get ':params' do
        usecase, network, param_yaml = %i[usecase network params].map { |key| params[key] }
        read_params_yaml(usecase, network, param_yaml)
      end
    end
  end
end
