# frozen_string_literal: true

require 'grape'
require 'lib/api/rest_api_base'
require_relative 'usecase/usecase_network'

module NetomoxExp
  module ApiRoute
    # namespace /usecase
    class Usecase < RestApiBase
      resource ':usecase' do
        mount ApiRoute::UsecaseNetwork
      end
    end
  end
end
