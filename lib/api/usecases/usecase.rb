# frozen_string_literal: true

require 'grape'
require_relative 'usecase/usecase_network'

module NetomoxExp
  module ApiRoute
    # namespace /usecase
    class Usecase < Grape::API
      resource ':usecase' do
        mount ApiRoute::UsecaseNetwork
      end
    end
  end
end
