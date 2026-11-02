# frozen_string_literal: true

module NetomoxExp
  module Netoviz2
    # Builder of the supports response
    class SupportsBuilder
      # @param [Model] model Model
      def initialize(model)
        @model = model
      end

      # @return [Hash]
      def build
        { supports: @model.supports.map { |edge| { kind: edge.kind, from: edge.from, to: edge.to } } }
      end
    end
  end
end
