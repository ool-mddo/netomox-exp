# frozen_string_literal: true

require 'grape'
require_relative 'usecases/usecase'

module NetomoxExp
  module ApiRoute
    # namespace /usecases
    class Usecases < Grape::API
      namespace 'usecases' do
        mount ApiRoute::Usecase
      end
    end
  end
end
