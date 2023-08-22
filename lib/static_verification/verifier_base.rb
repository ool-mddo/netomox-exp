# frozen_string_literal: true

require 'netomox'

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

      @log_messages = []
      @bgp_proc_nw = network
    end

    protected

    # @param [Hash] log_message A log message
    # @param [String] severity
    # @return [Boolean] true if message severity is more severe than specified severity
    def upper_severity?(log_message, severity)
      severities = %i[fatal error warn info debug]
      target_index = severities.find_index(severity.downcase.to_sym) || (severities.length - 1)
      msg_index = severities.find_index(log_message[:severity])
      msg_index <= target_index
    end

    # @param [Symbol] severity Severity of the log message
    # @param [String] target Target object (topology object)
    # @param [String] message Log message
    # @return [void]
    def add_log_message(severity, target, message)
      @log_messages.push({ severity:, target:, message: })
    end
  end
end
