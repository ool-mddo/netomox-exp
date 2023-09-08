# frozen_string_literal: true

require 'netomox'
require_relative 'verifier_base'

module NetomoxExp
  module StaticVerifier
    # bgp-proc verifier
    class BgpProcVerifier < VerifierBase
      # @param [Netomox::Topology::Networks] networks Networks object
      # @param [String] layer Layer name to handle
      def initialize(networks, layer)
        super(networks, layer, Netomox::NWTYPE_MDDO_BGP_PROC)
      end

      # @param [String] severity Base severity
      def verify(severity)
        verify_layer(severity) do
          verify_all_links { |bgp_proc_link| verify_peer_params(bgp_proc_link) }
          verify_all_node_tps { |bgp_proc_node, bgp_proc_tp| verify_node_tp_asn(bgp_proc_node, bgp_proc_tp) }
        end
      end

      private

      # @param [Netomox::Topology::Node] node Node (bgp-proc)
      # @param [Netomox::Topology::TermPoint] term_point TermPoint of the node (bgp-proc)
      # @return [void]
      def verify_node_tp_asn(node, term_point)
        node_cfid = node.attribute.confederation_id
        return unless node_cfid.positive?

        unless node.attribute.confederation_members.include?(term_point.attribute.local_as)
          add_log_message(:error, term_point.path, 'Peer confederation-id is not included node')
        end

        return unless node_cfid != term_point.attribute.confederation

        add_log_message(:error, term_point.path, 'Peer confederation-id is mismatch with node')
      end

      # @param [String] link_path Link path
      # @param [Netomox::Topology::TermPoint] src_tp Source term-point
      # @param [Netomox::Topology::TermPoint] dst_tp Destination term-point
      # @return [void]
      def verify_peer_asn_ip(link_path, src_tp, dst_tp)
        # alias
        stp_attr = src_tp.attribute
        dtp_attr = dst_tp.attribute

        # NOTE: check src_tp.remote_as/ip == dst_tp.local_as/ip
        #   will be check src_tp.local_as/ip == dst_tp.remote_as/ip in reverse-link (bidirectional link)

        # NOTE: switch dst local_as when confederation config is not equal
        dst_local_as = dtp_attr.local_as
        if stp_attr.confederation != dtp_attr.confederation && dtp_attr.confederation.positive?
          dst_local_as = dtp_attr.confederation
        end

        return if stp_attr.remote_as == dst_local_as && stp_attr.remote_ip == dtp_attr.local_ip

        add_log_message(:error, link_path, 'ASN/IP does not correspond')
      end

      # @param [String] link_path Link path
      # @param [Netomox::Topology::TermPoint] src_tp Source term-point
      # @param [Netomox::Topology::TermPoint] dst_tp Destination term-point
      # @return [void]
      def verify_timer(link_path, src_tp, dst_tp)
        return if src_tp.attribute.timer == dst_tp.attribute.timer

        add_log_message(:error, link_path, 'Timer params does not correspond')
      end

      # @param [Netomox::Topology::Link] link A link of bgp_proc network
      # @return [void]
      def verify_peer_params(link)
        _, src_tp = @target_nw.find_node_tp_by_edge(link.source)
        _, dst_tp = @target_nw.find_node_tp_by_edge(link.destination)
        verify_peer_asn_ip(link.path, src_tp, dst_tp)
        verify_timer(link.path, src_tp, dst_tp)
      end
    end
  end
end
