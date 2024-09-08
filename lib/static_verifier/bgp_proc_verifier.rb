# frozen_string_literal: true

require 'netomox'
require_relative 'verifier_base'

module NetomoxExp
  module StaticVerifier
    # rubocop:disable Metrics/ClassLength

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
          verify_all_nodes { |bgp_proc_node| verify_bgp_policy_refs(bgp_proc_node) }
        end
      end

      private

      # @param [Netomox::Topology::MddoBgpProcNodeAttribute] attribute Node attribute (bgp-proc)
      # @param [Netomox::Topology::MddoBgpPolicyAction] action Action of a bgp-policy statement
      # @return [nil, Netomox::Topology::SubAttributeBase] nil if not found reference
      def find_bgp_policy_action_ref(attribute, action)
        case action
        when Netomox::Topology::MddoBgpPolicyActionApply
          attribute.policies.find { |p| p.name == action.apply }
        when Netomox::Topology::MddoBgpPolicyActionCommunity
          attribute.community_sets.find { |c| c.name == action.community.name }
        else
          action
        end
      end

      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

      # @param [Netomox::Topology::MddoBgpProcNodeAttribute] attribute Node attribute (bgp-proc)
      # @param [Netomox::Topology::MddoBgpPolicyCondition] condition Condition of a bgp-policy statement
      # @return [nil, Array<Hash>, Netomox::Topology::SubAttributeBase] nil if not found reference
      #   NOTE: Array<Hash>...check result of multiple conditions
      def find_bgp_policy_condition_ref(attribute, condition)
        case condition
        when Netomox::Topology::MddoBgpPolicyConditionPolicy
          attribute.policies.find { |p| p.name == condition.policy }
        when Netomox::Topology::MddoBgpPolicyConditionAsPathGroup
          attribute.as_path_sets.find { |a| a.group_name == condition.as_path_group }
        when Netomox::Topology::MddoBgpPolicyConditionCommunity
          condition.communities.map do |cond_community|
            result = attribute.community_sets.find { |c| c.name == cond_community }
            { result:, condition: }
          end
        when Netomox::Topology::MddoBgpPolicyConditionPrefixList
          attribute.prefix_sets.find { |p| p.name == condition.prefix_list }
        when Netomox::Topology::MddoBgpPolicyConditionPrefixListFilter
          attribute.prefix_sets.find { |p| p.name == condition.prefix_list_filter.prefix_list }
        else
          condition
        end
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

      # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity, Metrics/BlockLength

      # @param [Netomox::Topology::Node] node Node (bgp-proc)
      # @return [void]
      def verify_bgp_policy_refs(node)
        node.attribute.policies.each do |policy|
          policy.default.actions.each do |action|
            next if find_bgp_policy_action_ref(node.attribute, action)

            msg = "Action reference is not found, #{action.to_data} in statement:default of policy:#{policy.name}"
            add_log_message(:error, node.path, msg)
          end
          policy.statements.each do |statement|
            msg_suffix = "in statement:#{statement.name} of policy:#{policy.name}"
            statement.actions.each do |action|
              next if find_bgp_policy_action_ref(node.attribute, action)

              msg = "Action reference is not found, #{action.to_data} #{msg_suffix}"
              add_log_message(:error, node.path, msg)
            end
            statement.conditions.each do |condition|
              find_data = find_bgp_policy_condition_ref(node.attribute, condition)
              if find_data.is_a?(Array)
                find_data.each do |find_datum|
                  next if find_datum[:result]

                  msg = "Condition reference is not found, #{condition.to_data};#{find_datum[:condition]} #{msg_suffix}"
                  add_log_message(:error, node.path, msg)
                end
                next
              end
              next if find_data

              msg = "Condition reference is not found, #{condition.to_data} #{msg_suffix}"
              add_log_message(:error, node.path, msg)
            end
          end
        end
      end
      # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity, Metrics/BlockLength

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
    # rubocop:enable Metrics/ClassLength
  end
end
