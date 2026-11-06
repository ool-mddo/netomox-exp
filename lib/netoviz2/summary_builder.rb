# frozen_string_literal: true

module NetomoxExp
  module Netoviz2
    # Builder of the summary response (see docs/netoviz2_data_format.md)
    class SummaryBuilder
      SCHEMA_VERSION = '1'

      # @param [Model] model Model
      # @param [String] network Network name
      # @param [String] snapshot Snapshot name
      # @param [String] etag ETag of the topology data
      def initialize(model, network:, snapshot:, etag:)
        @model = model
        @network = network
        @snapshot = snapshot
        @etag = etag
      end

      # @return [Hash]
      def build
        {
          schema_version: SCHEMA_VERSION, network: @network, snapshot: @snapshot, etag: @etag,
          flags: @model.flags, has_diff: @model.diff?, layers: layers,
          warnings: @model.warnings.to_a, warnings_total: @model.warnings.total
        }
      end

      private

      # @return [Array<Hash>] ordered by rank (layers in a cycle are the last)
      def layers
        sorted = @model.layers.sort_by { |layer| [@model.layer_graph.ranks[layer.id] || Float::INFINITY, layer.id] }
        sorted.map { |layer| layer_data(layer) }
      end

      def layer_data(layer)
        identity(layer).merge(
          supports: @model.layer_graph.supports[layer.id], rank: @model.layer_graph.ranks[layer.id],
          counts: counts(layer)
        )
      end

      def identity(layer)
        kinds = layer.network.network_types.keys
        data = { id: layer.id, name: layer.network.name, kind: kinds.first }
        data[:kinds] = kinds if kinds.size > 1
        data
      end

      def counts(layer)
        { nodes: layer.nodes.size, tps: layer.nodes.sum { |node| node.tps.size }, links: layer.links.size }
      end
    end
  end
end
