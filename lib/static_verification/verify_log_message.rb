# frozen_string_literal: true

module NetomoxExp
  # log-message
  class VerifyLogMessage
    # priority sequence of severities
    SEVERITIES = %i[fatal error warn info debug unknown].freeze

    # @!attribute [r] severity
    #   @return [Symbol]
    # @!attribute [r] target
    #   @return [String]
    # @!attribute [r] message
    #   @return [String]
    attr_reader :severity, :target, :message

    # @param [String,Symbol] severity Log severity (fatal,error,warning,info,debug & unknown)
    # @param [String] target Target network object in a topology data
    # @param [String] message Log message
    def initialize(severity: :unknown, target: '', message: '')
      @severity = normalize_severity(severity)
      @target = target
      @message = message
    end

    # @return [Hash] Log message data
    def to_hash
      {
        severity: @severity,
        target: @target,
        message: @message
      }
    end

    # @param [String,Symbol] base_severity Base severity
    # @return [Boolean] true if message severity is more severe than base severity
    def upper_severity?(base_severity)
      base_priority = SEVERITIES.find_index(normalize_severity(base_severity)) || (severities.length - 1)
      message_priority = SEVERITIES.find_index(@severity) # normalized
      message_priority <= base_priority
    end

    private

    # rubocop:disable Metrics/MethodLength

    # @param [String,Symbol] candidate_severity Severity info before normalizing
    # @return [Symbol] normalized severity
    def normalize_severity(candidate_severity)
      candidate_severity = candidate_severity.is_a?(String) ? candidate_severity.to_sym : candidate_severity
      case candidate_severity
      when /fatal/i
        :fatal
      when /err(or)?/i
        :error
      when /warn(ing)?/i
        :warn
      when /info(rmation)?/i
        :info
      when /debug/i
        :debug
      else
        :unknown
      end
    end
    # rubocop:enable Metrics/MethodLength
  end
end
