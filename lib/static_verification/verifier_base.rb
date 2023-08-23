# frozen_string_literal: true

require 'netomox'
require_relative 'verify_log_message'

module NetomoxExp
  module StaticVerifier
    # bgp-proc verifier
    class VerifierBase
      # @param [Netomox::Topology::Networks] networks Networks object
      # @param [String] layer Layer name to handle
      # @param [String] network_type Layer (network) type
      def initialize(networks, layer, network_type)
        network = networks.find_network(layer)

        raise StandardError, "Layer:#{layer} is not found" if network.nil?
        unless network.network_types.keys.include?(network_type)
          raise StandardError, "Layer:#{layer} type is not #{network_type}"
        end

        @log_messages = [] # [Array<VerifyLogMessage>]
        @target_nw = network
      end

      protected

      # @param [Symbol] severity Severity of the log message
      # @param [String] target Target object (topology object)
      # @param [String] message Log message
      # @return [void]
      def add_log_message(severity, target, message)
        @log_messages.push(VerifyLogMessage.new(severity:, target:, message:))
      end

      # common verify functions

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

      # @param [Netomox::Topology::TpRef] edge Link edge
      # @return [Array(Netomox::Topology::Node, Netomox::Topology::TermPoint)]
      def find_node_tp_by_edge(edge)
        bgp_proc_node = @target_nw.find_node_by_name(edge.node_ref)
        bgp_proc_tp = bgp_proc_node.find_tp_by_name(edge.tp_ref)
        [bgp_proc_node, bgp_proc_tp]
      end

      # @yield verify operations for each link
      # @yieldparam [Netomox::Topology::Link] link Link
      # @yieldreturn [void]
      # @return [void]
      def verify_according_to_links(&block)
        @target_nw.links.each do |link|
          # common verification
          verify_link_pair(link)
          # layer specific verification (if given)
          block&.call(link)
        end
      end

      # @yield verify operations for each node/term-point
      # @yieldparam [Netomox::Topology::Node] node Node
      # @yieldparam [Netomox::Topology::TermPoint] tp TermPoint
      # @yieldreturn [void]
      # @return [void]
      def verify_according_to_nodes(&block)
        @target_nw.nodes.each do |node|
          node.termination_points.each do |tp|
            # common verification
            verify_unlinked_tp(node, tp)
            # layer specific verification (if given)
            block&.call(node, tp)
          end
        end
      end
    end
  end
end
