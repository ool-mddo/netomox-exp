# frozen_string_literal: true

require 'netomox'
require_relative 'verifier_base'

module NetomoxExp
  module StaticVerifier
    # Layer1 verifier
    class Layer1Verifier < VerifierBase
      # @param [Netomox::Topology::Networks] networks Networks object
      # @param [String] layer Layer name to handle
      def initialize(networks, layer)
        super(networks, layer, Netomox::NWTYPE_MDDO_L1)
      end

      # @param [String] severity Base severity
      # @return [Array<Hash>] Level-filtered description check results
      def verify(severity)
        super(severity)

        verify_all_links do |l1_link|
          # check only source interface because links are bidirectional
          _, src_tp = find_node_tp_by_edge(l1_link.source)
          return add_log_message(:error, target_str(src_tp, l1_link), 'term_point not found') unless src_tp

          verify_description(src_tp, l1_link)
        end

        export_log_messages(severity:)
      end

      private

      # @param [Netomox::Topology::TermPoint] term_point (Source) term-point of description check target
      # @param [Netomox::Topology::Link] link Target link
      # @return [String] target string
      def target_str(term_point, link)
        "#{term_point.path} of #{link.path}"
      end

      # @param [Netomox::Topology::TermPoint] term_point (Source) term-point of description check target
      # @param [Netomox::Topology::Link] link Target link
      # @return [void]
      def verify_description(term_point, link)
        if empty_descr?(term_point)
          add_log_message(:warn, target_str(term_point, link), 'Empty description')
        elsif correct_descr?(term_point, link.destination)
          add_log_message(:info, target_str(term_point, link), 'Correct')
        else
          add_log_message(:warn, target_str(term_point, link), 'Incorrect format')
        end
      end

      # @param [Netomox::Topology::TermPoint] term_point Target term-point
      # @return [Boolean] true if the description of the term_point is empty
      def empty_descr?(term_point)
        # respond_to?(attr) attr.descr.empty? result
        #        F                 -            T
        #        T                 T            T
        #        T                 F            F
        !term_point.attribute.respond_to?(:description) || term_point.attribute.description.empty?
      end

      # @param [Netomox::Topology::TermPoint] term_point Target term-point
      # @param [Netomox::Topology::TpRef] facing_edge Facing (destination) term-point of the term-point
      # @return [Boolean] true if the term-point description is correct format
      def correct_descr?(term_point, facing_edge)
        # description format: specify its destination interface information as: "to_HOST_INTERFACE"
        return false unless term_point.attribute.description =~ /to_(\S+)_(\S+)/

        descr_host = Regexp.last_match(1)
        descr_tp = Regexp.last_match(2)
        # ignore upper/loser case difference,
        # but abbreviated interface type is NOT allowed (e.g. GigabitEthernet0/0 <=> Gi0/0)
        descr_host&.downcase == facing_edge.node_ref.downcase && descr_tp&.downcase == facing_edge.tp_ref.downcase
      end
    end
  end
end
