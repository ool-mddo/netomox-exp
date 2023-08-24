# frozen_string_literal: true

require 'netomox'
require_relative 'verify_log_message'

module NetomoxExp
  module StaticVerifier
    # rubocop:disable Metrics/ClassLength

    # bgp-proc verifier
    class VerifierBase
      # @param [Netomox::Topology::Networks] networks Networks object
      # @param [String] layer Layer name to handle
      # @param [String] network_type Layer (network) type
      # @raise [StandardError] if layer not found or network-type mismatch
      def initialize(networks, layer, network_type)
        network = networks.find_network(layer)

        raise StandardError, "Layer:#{layer} is not found" if network.nil?
        unless network.network_types.keys.include?(network_type)
          raise StandardError, "Layer:#{layer} type is not #{network_type}"
        end

        @log_messages = [] # [Array<VerifyLogMessage>]
        @topology = networks
        @target_nw = network

        # verify base data structure
        verify_support_existence
        verify_link_existence
      end

      # @param [String] severity Base severity
      # @return [Array<Hash>] Level-filtered description check results
      def verify(severity)
        # common verification
        verify_all_links { |link| verify_link_pair(link) }
        verify_all_node_tps { |node, tp| verify_unlinked_tp(node, tp) }
        export_log_messages(severity:)
      end

      protected

      # @param [String] severity Base severity (default: debug)
      # @return [Array<Hash>] Level-filtered description check results
      def export_log_messages(severity: :debug)
        @log_messages.filter { |msg| msg.upper_severity?(severity) }.map(&:to_hash)
      end

      # @param [Netomox::Topology::Node] node L3 node
      # @return [Boolean]
      def segment_node?(node)
        # NOTE: only L3 and OSPF_AREA has node_type attribute
        node.attribute&.node_type == 'segment'
      end

      # @param [Symbol] severity Severity of the log message
      # @param [String] target Target object (topology object)
      # @param [String] message Log message
      # @return [void]
      def add_log_message(severity, target, message)
        @log_messages.push(VerifyLogMessage.new(severity:, target:, message:))
      end

      # @param [Netomox::Topology::TpRef] edge Link edge
      # @return [Array(Netomox::Topology::Node, Netomox::Topology::TermPoint)]
      def find_node_tp_by_edge(edge)
        node = @target_nw.find_node_by_name(edge.node_ref)
        term_point = node.find_tp_by_name(edge.tp_ref)
        [node, term_point]
      end

      # @yield verify operations for each link
      # @yieldparam [Netomox::Topology::Link] link Link
      # @yieldreturn [void]
      # @return [void]
      def verify_all_links(&)
        @target_nw.links.each(&)
      end

      # @yield verify operations for each node/term-point
      # @yieldparam [Netomox::Topology::Node] node Node
      # @yieldparam [Netomox::Topology::TermPoint] tp TermPoint
      # @yieldreturn [void]
      # @return [void]
      def verify_all_node_tps
        @target_nw.nodes.each do |node|
          node.termination_points.each do |tp|
            yield(node, tp)
          end
        end
      end

      # @yield verify operations for each node
      # @yieldparam [Netomox::Topology::Node] node Node
      # @yieldreturn [void]
      # @return [void]
      def verify_all_nodes(&)
        @target_nw.nodes.each(&)
      end

      private

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

        add_log_message(:warn, term_point.path, 'Standalone peer config (not connected)')
      end

      # @param [Netomox::Topology::SupportingNetwork] support_nw
      # @return [Boolean]
      def exists_network_support?(support_nw)
        !@topology.find_network(support_nw.ref_network).nil?
      end

      # @param [Netomox::Topology::SupportingNode] support_node
      # @return [Boolean]
      def exists_node_support?(support_node)
        !@topology.find_network(support_node.ref_network)
           &.find_node_by_name(support_node.ref_node).nil?
      end

      # @param [Netomox::Topology::SupportingTerminationPoint] support_tp
      # @return [Boolean]
      def exists_tp_support?(support_tp)
        !@topology.find_network(support_tp.ref_network)
           &.find_node_by_name(support_tp.ref_node)
           &.find_tp_by_name(support_tp.ref_tp).nil?
      end

      # @param [Netomox::Topology::Network] network
      # @return [void]
      def verify_network_support_existence(network)
        network.supports.each do |s_nw|
          next if exists_network_support?(s_nw)

          add_log_message(:error, network.path, "Support network:#{s_nw} is not found")
        end
      end

      # @param [Netomox::Topology::Node] node
      # @return [void]
      def verify_node_support_existence(node)
        node.supports.each do |s_node|
          next if exists_node_support?(s_node)

          add_log_message(:error, node.path, "Support node:#{s_node} is not found")
        end
      end

      # @param [Netomox::Topology::TermPoint] term_point
      # @return [void]
      def verify_tp_support_existence(term_point)
        term_point.supports.each do |s_tp|
          # check tp support ref
          next if exists_tp_support?(s_tp)

          add_log_message(:error, term_point.path, "Support tp:#{s_tp} is not found")
        end
      end

      # @return [void]
      def verify_support_existence
        @topology.networks.each do |network|
          verify_network_support_existence(network)
          network.nodes.each do |node|
            verify_node_support_existence(node)
            node.termination_points.each { |tp| verify_tp_support_existence(tp) }
          end
        end
      end

      # @param [Netomox::Topology::TpRef] edge Link edge
      # @return [Boolean] false if the edge referring object is not found
      def exists_link_edge_object?(edge)
        network = @topology.find_network(edge.network_ref)
        return false if network.nil?

        node = network.find_node_by_name(edge.node_ref)
        return false if node.nil?

        tp = node.find_tp_by_name(edge.tp_ref)
        !tp.nil?
      end

      # @return [void]
      def verify_link_existence
        @target_nw.links.each do |link|
          next if exists_link_edge_object?(link.source) && exists_link_edge_object?(link.destination)

          add_log_message(:fatal, link.path, 'Edge referring object is not found')
        end
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
