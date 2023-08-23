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
      # @return [Array<Hash>] Level-filtered description check results
      def verify(severity)
        verify_according_to_links
        verify_according_to_nodes
        @log_messages.filter { |msg| msg.upper_severity?(severity) }.map(&:to_hash)
      end
    end
  end
end
