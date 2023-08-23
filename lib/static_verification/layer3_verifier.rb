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
        verify_according_to_nodes do |node|
          next unless segment_node?(node)

          # for each segment-node
          verify_segment_prefix_ip(node)
        end
        verify_segment_prefix_overlap

        @log_messages.filter { |msg| msg.upper_severity?(severity) }.map(&:to_hash)
      end

      private

      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity

      # @param [Array<IPAddress::IPv4>] seg_prefixes Prefix-list of a segment node
      # @param [Netomox::Topology::Link] seg_src_link A link that source is a segment node
      # @return [void]
      def verify_seg_prefix_and_tp_ip(seg_prefixes, seg_src_link)
        _, node_tp = find_node_tp_by_edge(seg_src_link.destination)
        tp_ip_addrs = node_tp.attribute.ip_addrs.map { |ip| IPAddress::IPv4.new(ip) }

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
      # @param [Array<IPAddress::IPv4>] seg_prefixes Prefix-list of the segment node
      # @return [void]
      def verify_seg_connected_tp(seg_node, seg_prefixes)
        seg_node.termination_points.each do |seg_tp|
          seg_src_link = @target_nw.find_link_by_source(seg_node.name, seg_tp.name)
          verify_seg_prefix_and_tp_ip(seg_prefixes, seg_src_link)
        end
      end

      # @param [Netomox::Topology::Node] node Node (L3, segment node)
      # @return [Array<IPAddress>] Prefix of the node
      def all_prefixes_of_node(node)
        # prefix string "a.b.c.d/nn" => IPAddress object
        node.attribute.prefixes.map(&:prefix).map { |prefix| IPAddress::IPv4.new(prefix) }
      end

      # @param [Netomox::Topology::Node] seg_node Segment node
      # @return [void]
      def verify_segment_prefix_ip(seg_node)
        seg_prefixes = all_prefixes_of_node(seg_node)

        add_log_message(:warn, seg_node.path, 'Segment has multiple prefixes') if seg_prefixes.length > 1
        add_log_message(:error, seg_node.path, 'Segment does not have prefix') if seg_prefixes.empty?

        verify_seg_connected_tp(seg_node, seg_prefixes)
      end

      # @return [Array<Netomox::Topology::Node>] All segment nodes
      def all_segment_nodes
        @target_nw.nodes.filter { |node| segment_node?(node) }
      end

      # @return [Array<IPAddress::IPv4>] Prefixes of all segment nodes
      def all_segment_prefixes
        all_prefixes = all_segment_nodes.map { |seg_node| all_prefixes_of_node(seg_node) }
        all_prefixes.flatten
      end

      # @return [Array<IPAddress::IPv4>] Overlapped prefixes
      def find_all_overlap_prefixes
        all_prefixes = all_segment_prefixes
        puts "# DEBUG: all_prefixes : #{all_prefixes.map(&:to_string)}"
        overlap_prefixes = all_prefixes.map do |prefix|
          # ignore itself (#equal? compares object_id) and find all overlapped prefixes
          all_prefixes.reject { |p| p.equal?(prefix) }.find_all { |p| prefix.include?(p) }
        end
        puts "# DEBUG: overlap_prefixes : #{overlap_prefixes.flatten.map(&:to_string)}"
        overlap_prefixes.flatten
      end

      # @param [IPAddress::IPv4] prefix Prefix (object of "a.b.c.d/nn")
      # @return [Array<Netomox::Topology::Node>] Segment nodes which has prefix
      def find_all_seg_node_by_prefix(prefix)
        all_segment_nodes.find_all do |seg_node|
          # IPAddress#to_string -> "a.b.c.d/nn" format string
          seg_node.attribute.prefixes.map(&:prefix).include?(prefix.to_string)
        end
      end

      # @return [void]
      def verify_segment_prefix_overlap
        find_all_overlap_prefixes.each do |prefix|
          find_all_seg_node_by_prefix(prefix).each do |node|
            add_log_message(:warn, node.path, "It has overlapped prefix: #{prefix}")
          end
        end
      end
    end
  end
end
