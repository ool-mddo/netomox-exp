# frozen_string_literal: true

module NetomoxExp
  module Netoviz2
    # Diff label of a topology object
    #
    # `_diff_state_` exists in topology data even if the topology is not a diff
    # (netomox always outputs it, `forward=kept`). So the label is derived from the state,
    # not from the existence of `_diff_state_`.
    module DiffLabel
      module_function

      # @param [Netomox::Topology::TopoObjectBase] object Network, node, term-point or link
      # @return [String,nil] 'added', 'deleted' or 'changed' (nil if kept)
      def of(object)
        state = object.diff_state.detect
        state == :kept ? nil : state.to_s
      end
    end
  end
end
