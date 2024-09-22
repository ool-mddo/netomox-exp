# frozen_string_literal: true

require 'grape'
require_relative 'snapshot/usecase_data_by_topology'

module NetomoxExp
  module ApiRoute
    # namespace /snapshot
    class UsecaseSnapshot < Grape::API
      resource ':snapshot' do
        mount ApiRoute::UsecaseDataByTopology
      end
    end
  end
end
