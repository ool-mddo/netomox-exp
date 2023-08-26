# frozen_string_literal: true

require 'netomox'
require_relative 'verify_log_message'

module NetomoxExp
  module StaticVerifier
    # bgp-proc verifier
    class VerifierBase
      private

      # @param [Netomox::Topology::Node] node
      # @return [Boolean] true if all term-points of the node does not have operative link
      def standalone_node?(node)
        node.termination_points.all? do |tp|
          src_link = @target_nw.find_link_by_source(node.name, tp.name)
          src_link.nil? || !exists_link_edge_object?(src_link.destination)
        end
      end

      # @param [Netomox::Topology::Node] node
      # @return [void]
      def verify_standalone_node(node)
        add_log_message(:error, node.path, 'Node does not have term-points') if node.termination_points.empty?
        add_log_message(:warn, node.path, 'Standalone node (not connected)') if standalone_node?(node)
      end

      # @param [Netomox::Topology::Link] link A link of bgp_proc network
      # @return [void]
      def verify_link_count(link)
        # search irregular (multiple-link-connected) term-point
        src_link_count = @target_nw.find_all_links_by_source_edge(link.source)&.length
        return if src_link_count == 1

        add_log_message(:fatal, link.path, "Source term-point has many:#{src_link_count} links")
      end

      # @param [Netomox::Topology::Link] link A link of bgp_proc network
      # @return [void]
      def verify_link_pair(link)
        # search pair (reverse) link
        return if @target_nw.find_link(link.destination, link.source)

        add_log_message(:error, link.path, 'Reverse link is not found')
      end

      # @param [Netomox::Topology::Node] node A node of bgp_proc network
      # @param [Netomox::Topology::TermPoint] term_point A term-point of the node
      # @return [void]
      def verify_unlinked_tp(node, term_point)
        return if @target_nw.find_link_by_source(node.name, term_point.name)

        add_log_message(:warn, term_point.path, 'Unlinked term-point (not connected)')
      end

      # @param [Netomox::Topology::SupportingRefBase] support
      # @return [Boolean]
      def exists_supporting_object?(support)
        !@topology.find_object_by_support(support).nil?
      end

      # @return [void]
      def verify_network_support_existence
        @target_nw.supports.each do |s_nw|
          next if exists_supporting_object?(s_nw)

          add_log_message(:error, @target_nw.path, "Support network:#{s_nw} is not found")
        end
      end

      # @param [Netomox::Topology::Node] node
      # @return [void]
      def verify_node_support_existence(node)
        node.supports.each do |s_node|
          next if exists_supporting_object?(s_node)

          add_log_message(:error, node.path, "Support node:#{s_node} is not found")
        end
      end

      # @param [Netomox::Topology::TermPoint] term_point
      # @return [void]
      def verify_tp_support_existence(term_point)
        term_point.supports.each do |s_tp|
          # check tp support ref
          next if exists_supporting_object?(s_tp)

          add_log_message(:error, term_point.path, "Support tp:#{s_tp} is not found")
        end
      end

      # @return [void]
      def verify_support_existence
        # support network check
        verify_network_support_existence

        # support node/tp check
        @target_nw.nodes.each do |node|
          verify_node_support_existence(node)
          node.termination_points.each { |tp| verify_tp_support_existence(tp) }
        end
      end

      # @param [Netomox::Topology::TpRef] edge Link edge
      # @return [Boolean] false if the edge referring object is not found
      def exists_link_edge_object?(edge)
        !@topology.find_tp_by_edge(edge).nil?
      end

      # @return [void]
      def verify_link_existence
        @target_nw.links.each do |link|
          next if exists_link_edge_object?(link.source) && exists_link_edge_object?(link.destination)

          add_log_message(:fatal, link.path, 'Edge referring object is not found')
        end
      end
    end
  end
end
