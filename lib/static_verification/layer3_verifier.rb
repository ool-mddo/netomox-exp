# frozen_string_literal: true

require 'netomox'
require_relative 'verifier_base'

module NetomoxExp
  module StaticVerifier
    # Layer3 verifier
    class Layer3Verifier < VerifierBase
      # @param [Netomox::Topology::Networks] networks Networks object
      # @param [String] layer Layer name to handle
      def initialize(networks, layer)
        super(networks, layer, Netomox::NWTYPE_MDDO_L3)
      end

      # @param [String] severity Base severity
      # @return [Array<Hash>] Level-filtered description check results
      def verify(severity)
        verify_according_to_links
        verify_according_to_nodes
        verify_according_to_segments
        @log_messages.filter { |msg| msg.upper_severity?(severity) }.map(&:to_hash)
      end

      private

      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity

      # @param [Array<IPAddress>] seg_prefixes Prefix-list of a segment node
      # @param [Netomox::Topology::Link] seg_src_link A link that source is a segment node
      # @return [void]
      def verify_seg_prefix_and_tp_ip(seg_prefixes, seg_src_link)
        _, node_tp = find_node_tp_by_edge(seg_src_link.destination)
        tp_ip_addrs = node_tp.attribute.ip_addrs.map { |ip| IPAddress(ip) }

        add_log_message(:error, node_tp.path, 'Term-point has multiple ip-addresses') if tp_ip_addrs.length > 1
        add_log_message(:error, node_tp.path, 'Term-point does not have ip-address') if tp_ip_addrs.empty?

        tp_ip_addrs.each do |ip|
          next if seg_prefixes.any? { |prefix| prefix.include?(ip) && prefix.netmask == ip.netmask }

          msg = "Term-point IP is mismatch its connected segment node prefix, #{seg_src_link.source}"
          add_log_message(:error, node_tp.path, msg)
        end
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity

      # @param [Netomox::Topology::Node] seg_node Segment node
      # @param [Array<IPAddress>] seg_prefixes Prefix-list of the segment node
      # @return [void]
      def verify_seg_connected_tp(seg_node, seg_prefixes)
        seg_node.termination_points.each do |seg_tp|
          seg_src_link = @target_nw.find_link_by_source(seg_node.name, seg_tp.name)
          verify_seg_prefix_and_tp_ip(seg_prefixes, seg_src_link)
        end
      end

      # rubocop:disable Metrics/AbcSize

      # @yield verify operations for each segment-node
      # @yieldparam [Netomox::Topology::Node] seg_node Segment node
      # @yieldparam [Array<IPAddress>] prefixes of seg_node
      # @yieldreturn [void]
      # @return [void]
      def verify_according_to_segments
        @target_nw.nodes.filter { |node| segment_node?(node) }.each do |seg_node|
          seg_prefixes = seg_node.attribute.prefixes.map { |prefix| IPAddress(prefix.prefix) }

          add_log_message(:warn, seg_node.path, 'Segment has multiple prefixes') if seg_prefixes.length > 1
          add_log_message(:error, seg_node.path, 'Segment does not have prefix') if seg_prefixes.empty?

          verify_seg_connected_tp(seg_node, seg_prefixes)
        end
      end
      # rubocop:enable Metrics/AbcSize
    end
  end
end
