# frozen_string_literal: true

require 'netomox'
require_relative 'verifier_base'

module NetomoxExp
  module StaticVerifier
    # bgp-as verifier
    class BgpAsVerifier < VerifierBase
      # @param [Netomox::Topology::Networks] networks Networks object
      # @param [String] layer Layer name to handle
      def initialize(networks, layer)
        super(networks, layer, Netomox::NWTYPE_MDDO_BGP_AS)
      end

      # @param [String] severity Base severity
      def verify(severity)
        verify_layer(severity) do
          verify_all_nodes { |bgp_as_node| verify_support_asn(bgp_as_node) }
        end
      end

      private

      # rubocop:disable Metrics/MethodLength

      # @param [Netomox::Topology::Node] node BGP-AS node
      # @return [void]
      def verify_support_asn(node)
        node.supports.each do |node_support|
          as_number = node.attribute.as_number # alias
          # support-node of bgp-as node is bgp-proc node
          bgp_proc_node = @topology.find_object_by_support(node_support)
          if bgp_proc_node.nil?
            add_log_message(:error, node.path, "Support node:#{node_support} is not found")
            next
          end

          bgp_proc_node_cfid = bgp_proc_node.attribute.confederation_id
          next unless bgp_proc_node_cfid.positive?

          if bgp_proc_node_cfid != as_number
            add_log_message(:error, node.path, "Confederation ASN mismatch with support node:#{node_support}")
          end
        end
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
