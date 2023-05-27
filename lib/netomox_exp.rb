# frozen_string_literal: true

require 'logger'

# NetomoxExp Application (REST API server)
module NetomoxExp
  # module common logger
  @logger = Logger.new($stderr)
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
