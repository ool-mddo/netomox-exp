# frozen_string_literal: true

require 'netomox'
require_relative 'verifier_base'

module NetomoxExp
  module StaticVerifier
    # ospf-area verifier
    class OspfAreaVerifier < VerifierBase
      # @param [Netomox::Topology::Networks] networks Networks object
      # @param [String] layer Layer name to handle
      def initialize(networks, layer)
        super(networks, layer, Netomox::NWTYPE_MDDO_OSPF_AREA)
      end

      # @param [String] severity Base severity
      # @return [Array<Hash>] Level-filtered description check results
      def verify(severity)
        super(severity)

        verify_all_nodes do |node|
          next unless segment_node?(node)

          # for each segment-node
          verify_ospf_params(node)
        end

        export_log_messages(severity:)
      end

      private

      # @param [Array<Netomox::Topology::TermPoint>] node_tps A list of term-points of ospf-node
      #   that connected with a segment node
      # @yield attribute selection
      # @yieldparam [Netomox::Topology::AttributeBase] attribute Term-point attribute
      # @yieldreturn [Integer, String] an attribute value
      # @return [Boolean] true if all tp has same attribute value
      def uniq_value?(node_tps)
        values = node_tps.map { |tp| yield(tp.attribute) }
        values.uniq.length == 1
      end

      # @param [Netomox::Topology::Node] seg_node Segment node
      # @return [Array<Netomox::Topology::TermPoint>] Array of term-points
      #   (ospf-node tp: connected with the segment node)
      def term_points_connected_segment(seg_node)
        seg_src_links = seg_node.termination_points.map do |seg_tp|
          @target_nw.find_link_by_source(seg_node.name, seg_tp.name)
        end

        seg_src_links.map do |seg_src_link|
          _, node_tp = @target_nw.find_node_tp_by_edge(seg_src_link.destination)
          node_tp
        end
      end

      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize

      # @param [Netomox::Topology::Node] seg_node Segment node
      # @return [void]
      def verify_ospf_params(seg_node)
        node_tps = term_points_connected_segment(seg_node)

        # timer
        unless uniq_value?(node_tps) { |tp_attr| tp_attr.timer.hello_interval }
          add_log_message(:error, seg_node.path, 'Connected ospf-node has mismatch hello-interval')
        end
        unless uniq_value?(node_tps) { |tp_attr| tp_attr.timer.dead_interval }
          add_log_message(:error, seg_node.path, 'Connected ospf-node has mismatch dead-interval')
        end
        unless uniq_value?(node_tps) { |tp_attr| tp_attr.timer.retransmission_interval }
          add_log_message(:error, seg_node.path, 'Connected ospf-node has mismatch retransmission-interval')
        end

        # network-type
        return if uniq_value?(node_tps, &:network_type)

        add_log_message(:error, seg_node.path, 'Connected ospf-node has mismatch network-type')
      end
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize
    end
  end
end
