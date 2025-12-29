# frozen_string_literal: true

require 'grape'
require_relative 'rest_api_base'
require_relative 'usecases/usecase'

module NetomoxExp
  module ApiRoute
    # namespace /usecases
    class Usecases < RestApiBase
      namespace 'usecases' do
        mount ApiRoute::Usecase
      end
    end
  end
end
