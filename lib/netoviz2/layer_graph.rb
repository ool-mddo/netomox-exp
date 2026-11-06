# frozen_string_literal: true

module NetomoxExp
  module Netoviz2
    # Dependency graph between layers (networks) and the rank of each layer.
    #
    # A layer supports another layer when the network declares it (`supporting-network`)
    # or any node/tp/link of the layer actually refers to an object in the other layer.
    # The declaration and the actual references do not always match in real data,
    # so both are merged.
    class LayerGraph
      # @return [Hash{String=>Array<String>}] layer id => ids of supporting (lower) layers
      attr_reader :supports
      # @return [Hash{String=>Integer,nil}] layer id => rank (nil if the layer is in a cycle)
      attr_reader :ranks

      # @param [Array<String>] layer_ids Layer ids existing in the topology
      # @param [Hash{String=>Array<String>}] declared Declared supports (`supporting-network`)
      # @param [Hash{String=>Array<String>}] used Supports found from the objects' supports
      # @param [Warnings] warnings Warnings collector
      def initialize(layer_ids, declared, used, warnings)
        @layer_ids = layer_ids
        @warnings = warnings
        @supports = layer_ids.to_h do |id|
          [id, merge_supports(id, declared.fetch(id, []), used.fetch(id, []))]
        end
        @ranks = {}
        layer_ids.each { |id| rank_of(id, []) }
      end

      private

      def merge_supports(id, declared, used)
        declared.each do |ref|
          next if @layer_ids.include?(ref)

          @warnings.add('dangling_layer_support', 'info',
                        "supporting-network '#{ref}' of '#{id}' is not found in the topology", layer: id, ref:)
        end
        (declared + used).uniq.select { |ref| @layer_ids.include?(ref) && ref != id }.sort
      end

      # @param [String] id Layer id
      # @param [Array<String>] stack Layer ids being visited (to detect cycles)
      # @return [Integer,nil]
      def rank_of(id, stack)
        return @ranks[id] if @ranks.key?(id)

        if stack.include?(id)
          report_cycle((stack + [id])[stack.index(id)..])
          return nil
        end

        ranks = @supports[id].map { |ref| rank_of(ref, stack + [id]) }
        @ranks[id] = ranks.include?(nil) ? nil : (ranks.max || -1) + 1
      end

      def report_cycle(path)
        @warnings.add('layer_support_cycle', 'warn',
                      "layers support each other: #{path.join(' -> ')}", layers: path)
      end
    end
  end
end
