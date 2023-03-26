# frozen_string_literal: true

require 'grape'

# NetomoxExp Application (REST API server)
module NetomoxExp
  # Rest api base class
  class RestApiBase < Grape::API
    format :json

    helpers do
      # @return [Logger] Logger
      def logger
        RestApiBase.logger
      end
    end
  end

  # module common logger
  @logger = RestApiBase.logger
  @logger.progname = 'netomox-exp'
  @logger.level = case ENV.fetch('NETOMOX_EXP_LOG_LEVEL', 'info')
                  when /fatal/i
                    Logger::FATAL
                  when /error/i
                    Logger::ERROR
                  when /warn/i
                    Logger::WARN
                  when /debug/i
                    Logger::DEBUG
                  else
                    Logger::INFO # default
                  end

  module_function

  # @return [Logger] Logger
  def logger
    @logger
  end
end
