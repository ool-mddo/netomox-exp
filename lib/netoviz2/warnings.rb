# frozen_string_literal: true

module NetomoxExp
  module Netoviz2
    # Collector of inconsistencies found while building the netoviz2 view-model.
    # The API does not fail with them. The clients show them.
    class Warnings
      # Max number of warnings kept (the total count is always counted)
      LIMIT = 100

      attr_reader :total

      def initialize
        @items = []
        @total = 0
      end

      # @param [String] code Warning code (see docs/netoviz2_data_format.md)
      # @param [String] severity 'info' or 'warn'
      # @param [String] message Message
      # @param [Hash] detail Additional fields
      # @return [void]
      def add(code, severity, message, **detail)
        @total += 1
        return if @items.size >= LIMIT

        @items << { code:, severity:, message: }.merge(detail)
      end

      # @return [Array<Hash>]
      def to_a
        @items.dup
      end
    end
  end
end
