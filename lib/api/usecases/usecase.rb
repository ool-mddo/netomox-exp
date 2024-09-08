# frozen_string_literal: true

require 'grape'
require_relative 'usecase/usecase_data_ops'

module NetomoxExp
  module ApiRoute
    # namespace /usecase
    class Usecase < Grape::API
      resource ':usecase' do
        mount ApiRoute::UsecaseDataOps
      end
    end
  end
end
