# frozen_string_literal: true

require 'grape'
require 'lib/netomox_exp'
require_relative 'helpers'
require_relative 'helpers_usecase'

module NetomoxExp
  # Rest api base class
  class RestApiBase < Grape::API
    format :json
    logger NetomoxExp.logger
    helpers Helpers

    helpers do
      # @return [Logger] Logger
      def logger
        RestApiBase.logger
      end
    end
  end
end
