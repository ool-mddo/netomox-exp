# frozen_string_literal: true

require 'grape'
require 'lib/api/usecases/usecase/usecase_helpers'

module NetomoxExp
  module ApiRoute
    # usecase parameter handling
    class UsecaseDataByFile < Grape::API
      desc 'Get flow data (csv -> json)'
      get 'flows/:file_name' do
        usecase, network, flow_file = %i[usecase network file_name].map { |key| params[key] }
        read_flow_data(usecase, network, flow_file)
      end

      desc 'Get usecase params (yaml -> json)'
      get ':params' do
        usecase, network, param_yaml = %i[usecase network params].map { |key| params[key] }
        read_params_yaml(usecase, network, param_yaml)
      end
    end
  end
end
