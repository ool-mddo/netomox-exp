# frozen_string_literal: true

require 'netomox'
require_relative 'verify_log_message'
require_relative 'verifier_base_common'

module NetomoxExp
  module StaticVerifier
    # bgp-proc verifier
    class VerifierBase
      # @param [Netomox::Topology::Networks] networks Networks object
      # @param [String] layer Layer name to handle
      # @param [String] network_type Layer (network) type
      # @raise [StandardError] if layer not found or network-type mismatch
      def initialize(networks, layer, network_type)
        network = networks.find_network(layer)

        raise StandardError, "Layer:#{layer} is not found" if network.nil?
        raise StandardError, "Layer:#{layer} type is not #{network_type}" unless network.network_type?(network_type)

        @log_messages = [] # [Array<VerifyLogMessage>]
        @topology = networks
        @target_nw = network
      end

      # @param [String] severity Base severity
      # @return [Array<Hash>] Level-filtered description check results
      def verify(severity)
        # verify common data structure
        verify_support_existence
        verify_link_existence
        verify_all_links do |link|
          verify_link_pair(link)
          verify_link_count(link)
        end
        verify_all_node_tps { |node, tp| verify_unlinked_tp(node, tp) }
        verify_all_nodes { |node| verify_standalone_node(node) }

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
    end
  end
end
