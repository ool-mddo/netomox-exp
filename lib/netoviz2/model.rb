# frozen_string_literal: true

require 'lib/netoviz2/object_id'
require 'lib/netoviz2/warnings'
require 'lib/netoviz2/layer_graph'
require 'lib/netoviz2/entries'

module NetomoxExp
  module Netoviz2
    # Structural model for netoviz2, built from a netomox topology instance
    # (`Netomox::Topology::Networks`). Objects are given IDs (see ObjectId), and supports are resolved.
    # Inconsistencies are not errors; they are collected in `warnings`.
    class Model
      # Target ID of a support (data of a support is `to_data` of netomox support object)
      SUPPORT_TARGET_ID = {
        node: ->(s) { ObjectId.node(s['network-ref'], s['node-ref']) },
        tp: ->(s) { ObjectId.tp(s['network-ref'], s['node-ref'], s['tp-ref']) },
        link: ->(s) { ObjectId.link(s['network-ref'], s['link-ref']) }
      }.freeze

      # @return [Array<LayerEntry>] in the order of the topology data
      attr_reader :layers
      # @return [Array<SupportEdge>]
      attr_reader :supports
      # @return [Warnings]
      attr_reader :warnings
      # @return [LayerGraph]
      attr_reader :layer_graph

      # @param [Netomox::Topology::Networks] networks Topology instance
      def initialize(networks)
        @networks = networks
        @warnings = Warnings.new
        @entries = {}
        @diff_ids = []
        @layers = []
        @supports = []
        build_layers
        @used_layer_supports = Hash.new { |h, k| h[k] = [] }
        collect_supports
        @layer_graph = LayerGraph.new(@layers.map(&:id), declared_layer_supports, @used_layer_supports, @warnings)
      end

      # @param [String] id Object ID
      # @return [Entry,nil]
      def entry(id)
        @entries[id]
      end

      # @param [String] id Layer ID
      # @return [LayerEntry,nil]
      def layer(id) = @layers.find { |layer| layer.id == id }

      # @return [Array<String>] `flag` of networks-attributes (`mddo-topology:networks-attributes`)
      def flags
        attr = @networks.attribute
        return [] if attr.nil? || attr.empty?

        attr.to_data['flag'] || []
      end

      # @return [Boolean] true if any object has diff state other than `kept`
      def diff?
        !@diff_ids.empty?
      end

      private

      def build_layers
        @networks.networks.each do |network|
          id = ObjectId.layer(network.name)
          next unless register(id, :layer, id, network)

          layer = LayerEntry.new(id, network, [], [])
          @layers << layer
          network.nodes.each { |node| build_node(layer, node) }
          network.links.each { |link| build_link(layer, link) }
        end
      end

      def build_node(layer, node)
        id = ObjectId.node(layer.network.name, node.name)
        return unless register(id, :node, layer.id, node)

        entry = NodeEntry.new(id, node, [])
        layer.nodes << entry
        node.termination_points.each { |tp| build_tp(layer, entry, tp) }
      end

      def build_tp(layer, node_entry, term_point)
        id = ObjectId.tp(layer.network.name, node_entry.node.name, term_point.name)
        node_entry.tps << TpEntry.new(id, node_entry.id, term_point) if register(id, :tp, layer.id, term_point)
      end

      def build_link(layer, link)
        id = ObjectId.link(layer.network.name, link.name)
        return unless register(id, :link, layer.id, link)

        src_id = endpoint_id(layer, link, link.source)
        dst_id = endpoint_id(layer, link, link.destination)
        layer.links << LinkEntry.new(id, link, src_id, dst_id)
      end

      # @return [String,nil] tp ID of the link endpoint (nil if the tp is not found)
      def endpoint_id(layer, link, tp_ref)
        id = ObjectId.tp(layer.network.name, tp_ref.node_ref, tp_ref.tp_ref)
        return id if @entries[id]&.type == :tp

        @warnings.add('dangling_link_endpoint', 'warn',
                      "link '#{link.name}' refers to '#{tp_ref.node_ref}/#{tp_ref.tp_ref}' that is not found",
                      link: ObjectId.link(layer.network.name, link.name))
        nil
      end

      # @return [Entry,nil] nil if the ID is already used (the later object is ignored)
      def register(id, type, layer_id, object)
        if @entries.key?(id)
          @warnings.add('duplicate_id', 'warn', "duplicated #{type} '#{object.name}' is ignored", id:)
          return nil
        end

        @diff_ids << id unless object.diff_state.detect == :kept
        @entries[id] = Entry.new(type, layer_id, object)
      end

      def declared_layer_supports
        @layers.to_h { |layer| [layer.id, layer.network.supports.map { |s| ObjectId.layer(s.to_data['network-ref']) }] }
      end

      def collect_supports
        @entries.each do |id, entry|
          next unless SUPPORT_TARGET_ID.key?(entry.type)

          entry.object.supports.each { |support| add_support(entry.type, id, entry.layer_id, support.to_data) }
        end
      end

      # @param [Symbol] kind :node, :tp or :link
      # @param [Hash] data Data of the support (`to_data` of netomox support object)
      def add_support(kind, from_id, layer_id, data)
        to_id = SUPPORT_TARGET_ID.fetch(kind).call(data)
        target = @entries[to_id]
        if target&.type == kind
          @supports << SupportEdge.new(kind.to_s, from_id, to_id)
          @used_layer_supports[layer_id] << target.layer_id
        else
          @warnings.add('dangling_support', 'warn', "#{kind} support target '#{to_id}' is not found",
                        kind: kind.to_s, from: from_id, ref: to_id)
        end
      end
    end
  end
end
