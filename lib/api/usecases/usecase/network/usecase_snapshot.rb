# frozen_string_literal: true

require 'lib/api/rest_api_base'
require_relative 'snapshot/usecase_data_by_topology'
require_relative 'snapshot/blueprint_topology'

module NetomoxExp
  module ApiRoute
    # namespace /snapshot
    class UsecaseSnapshot < RestApiBase
      resource ':snapshot' do
        mount ApiRoute::UsecaseDataByTopology
        mount ApiRoute::BlueprintTopology
      end
    end
  end
end
