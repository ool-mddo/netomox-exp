# frozen_string_literal: true

require 'lib/api/rest_api_base'
require_relative 'snapshot/usecase_data_by_topology'

module NetomoxExp
  module ApiRoute
    # namespace /snapshot
    class UsecaseSnapshot < RestApiBase
      resource ':snapshot' do
        mount ApiRoute::UsecaseDataByTopology
      end
    end
  end
end
