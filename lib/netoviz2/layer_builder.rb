# frozen_string_literal: true

require 'lib/netoviz2/diff_label'

module NetomoxExp
  module Netoviz2
    # Builder of the layer response: structure only (no attributes)
    class LayerBuilder
      # @param [Model] model Model
      def initialize(model)
        @model = model
      end

      # @param [String] layer_id Layer ID
      # @return [Hash,nil] nil if the layer is not found
      def build(layer_id)
        layer = @model.layer(layer_id)
        return nil unless layer

        {
          layer: layer.id,
          nodes: layer.nodes.map { |node| node_data(node) },
          tps: layer.nodes.flat_map { |node| node.tps.map { |tp| tp_data(tp) } },
          links: layer.links.map { |link| link_data(link) }
        }
      end

      private

      def node_data(entry)
        node = entry.node
        data = { id: entry.id, name: node.name, tp_count: entry.tps.size }
        kind = node_kind(node)
        data[:kind] = kind if kind
        with_diff(data, node)
      end

      # @return [String,nil] `node-type` in the node attribute if exists
      def node_kind(node)
        node.attribute.empty? ? nil : node.attribute.to_data['node-type']
      end

      def tp_data(entry)
        with_diff({ id: entry.id, node: entry.node_id, name: entry.tp.name }, entry.tp)
      end

      # NOTE: src/dst is nil if the endpoint is not found (kept as null)
      def link_data(entry)
        with_diff({ id: entry.id, name: entry.link.name, src: entry.src_id, dst: entry.dst_id }, entry.link)
      end

      # add `diff` only if the object is added/deleted/changed
      def with_diff(data, object)
        label = DiffLabel.of(object)
        data[:diff] = label if label
        data
      end
    end
  end
end
