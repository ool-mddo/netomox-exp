# frozen_string_literal: true

require 'netomox'
require_relative 'verify_log_message'

module NetomoxExp
  # bgp-proc verifier
  class VerifierBase
    # @param [Netomox::Topology::Networks] networks Networks object
    # @param [String] layer Layer name to handle
    def initialize(networks, layer)
      network = networks.find_network(layer)

      raise StandardError, "Layer:#{layer} is not found" if network.nil?
      unless network.network_types.keys.include?(Netomox::NWTYPE_MDDO_BGP_PROC)
        raise StandardError, "Layer:#{layer} is not bgp-proc"
      end

      @log_messages = [] # [Array<VerifyLogMessage>]
      @bgp_proc_nw = network
    end

    protected

    # @param [Symbol] severity Severity of the log message
    # @param [String] target Target object (topology object)
    # @param [String] message Log message
    # @return [void]
    def add_log_message(severity, target, message)
      @log_messages.push(VerifyLogMessage.new(severity:, target:, message:))
    end
  end
end
