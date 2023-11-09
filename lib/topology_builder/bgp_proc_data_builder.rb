# frozen_string_literal: true

require 'ipaddr'
require_relative 'pseudo_model'
require_relative 'csv_mapper/bgp_peer_conf_table'
require_relative 'csv_mapper/bgp_proc_conf_table'

module NetomoxExp
  module TopologyBuilder
    # rubocop:disable Metrics/ClassLength

    # BGP data builder
    class BgpProcDataBuilder < DataBuilderBase
      # @param [String] target Target network (config) data name
      # @param [Netomox::PseudoDSL::PNetwork] layer3p Layer3 network topology
      def initialize(target:, layer3p:, debug: false)
        super(debug:)
        @layer3p = layer3p
        @bgp_peer_conf = CSVMapper::BgpPeerConfigurationTable.new(target)
        @bgp_proc_conf = CSVMapper::BgpProcessConfigurationTable.new(target)
        @named_structures = CSVMapper::NamedStructuresTable.new(target)
      end

      # @return [Netomox::PseudoDSL::PNetworks] Networks contains bgp topology
      def make_networks
        # setup bgp layer
        @network = @networks.network('bgp_proc')
        @network.type = Netomox::NWTYPE_MDDO_BGP_PROC
        @network.attribute = { name: 'mddo-bgp-network' }
        # setup bgp layer
        setup_bgp_node_tp
        setup_bgp_link
        update_bgp_attribute

        # return networks contains bgp layer
        @networks
      end

      private

      # @param [String] remote_ip Peer address (remote ip) of a term-point
      # @return [String] name of the term-point that has remote_ip peer
      def peer_tp_name(remote_ip)
        "peer_#{remote_ip}"
      end

      # @param [String] local_ip Local ip address (endpoint of a link)
      # @param [String] remote_ip Remote ip address (endpoint of a link)
      # @return [Array(Netomox::PseudoDSL::PNode, Netomox::PseudoDSL::PTermPoint), Array(nil, nil)]
      #   A pair of node and term-point = source of the link
      def find_bgp_node_tp_by_ip_pair(local_ip, remote_ip)
        # find bgp layer (network)
        @network.nodes.each do |node|
          tp = node.tps.find do |term_point|
            term_point.attribute[:local_ip] == local_ip && term_point.attribute[:remote_ip] == remote_ip
          end
          next if tp.nil?

          return [node, tp]
        end
        [nil, nil]
      end

      # @param [Netomox::PseudoDSL::PTermPoint] l3_tp Layer3 term-point
      # @param [String] ip_addr IP address ("a.b.c.d")
      # @return [String, nil] Found IP address ("a.b.c.d/nn" that includes ip_addr)
      def find_ip_in_l3_tp_includes(l3_tp, ip_addr)
        # NOTE: bgp-multihop or faulty L3 attribute case
        return nil if l3_tp.nil? || l3_tp.attribute.nil? || !l3_tp.attribute.key?(:ip_addrs)

        l3_tp.attribute[:ip_addrs].find { |ip| IPAddr.new(ip).include?(ip_addr) }
      end

      # @param [String] ip_string IP address string with prefix (ex: "192.168.0.3/24")
      # @return [String] IP address string without prefix (ex: "192.168.0.3")
      def ip_string_without_prefix(ip_string)
        ip_string.gsub(%r{/\d+$}, '')
      end

      # rubocop:disable Metrics/MethodLength

      # @param [Netomox::PseudoDSL::PNode] bgp_local_node BGP node (local)
      # @param [String] remote_ip Peer (remote) IP address of the BGP node
      # @return [String] Local IP address
      # @raise [StandardError] A BGP node does not have support L3 node
      def find_local_ip_from_support_node(bgp_local_node, remote_ip)
        if bgp_local_node.supports.empty?
          raise StandardError, "bgp_local_node does not have support node: #{bgp_local_node.name}"
        end

        l3_local_node_name = bgp_local_node.supports[0][1]
        l3_local_tp = find_l3_tp_by_ip(l3_local_node_name, remote_ip)
        if l3_local_tp.nil?
          # NOTE: bgp-multihop or faulty L3 attribute case
          @logger.warn "underlay L3 of #{bgp_local_node.name}, #{l3_local_node_name} does not have remote-linked tp " \
                       "or peer #{remote_ip} is bgp-multihop?"
          return ''
        end

        l3_local_ip = find_ip_in_l3_tp_includes(l3_local_tp, remote_ip)
        debug_print "#     -> l3_local_tp: #{l3_local_node_name} : l3_local_ip: #{l3_local_ip}"
        ip_string_without_prefix(l3_local_ip)
      end
      # rubocop:enable Metrics/MethodLength

      # @param [Netomox::PseudoDSL::PNode] bgp_local_node BGP node (local)
      # @param [Netomox::PseudoDSL::PTermPoint] bgp_local_tp Term point of the BGP node (local)
      # @return [void]
      def add_bgp_tp_support_for_ebgp_peer(bgp_local_node, bgp_local_tp)
        # for eBGP peer (external AS node),
        # remote node data does not exist but local node knows remote_ip
        #
        #   external AS node
        #   (not exist)
        #
        #   +----------+ Remote IP      +---------+
        #   | (bgp     * o ---------- o * bgp     |
        #   |  remote) | :  (local IP): | local   |
        #   +----------+ :            : +---------+
        #        :       :            :      :
        #        V       :            :      V
        #   +----------+ V            V +---------+
        #   | (layer3  * o ---------- o * layer3  |
        #   |  remote) |                | local   |
        #   +----------+                +---------+
        #
        # So it assume that:
        # * local_ip does not exists: eBGP peer
        # * local_ip is a address of a tp in L3 supported node (L3 local)
        #   and the tp owns ip addr that in same L3 segment of remote_ip
        #
        remote_ip = bgp_local_tp.attribute[:remote_ip]
        debug_print "#   - (eBGP peer) remote_ip: #{remote_ip}"
        l3_local_ip = find_local_ip_from_support_node(bgp_local_node, remote_ip)
        add_bgp_tp_support(bgp_local_node, bgp_local_tp, l3_local_ip) unless l3_local_ip.empty?
      end

      # rubocop:disable Metrics/MethodLength

      # Complement support term-point info for all BGP term-points
      # @return [void]
      def complement_local_ip_in_tps
        debug_print '# complement_local_ip_in_tps'
        @network.nodes.each do |bgp_local_node|
          debug_print "# Target = local_node: #{bgp_local_node.name}"
          bgp_local_node.tps.each do |bgp_local_tp|
            local_ip = bgp_local_tp.attribute[:local_ip]
            debug_print "#   Target = local_tp: #{bgp_local_tp.name}, local_ip: #{local_ip}"
            unless local_ip.nil?
              add_bgp_tp_support(bgp_local_node, bgp_local_tp, local_ip)
              next
            end

            # eBGP peer (bgp_peer_conf record have remote_ip but not have local_ip)
            add_bgp_tp_support_for_ebgp_peer(bgp_local_node, bgp_local_tp)
          end
        end
      end
      # rubocop:enable Metrics/MethodLength

      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize

      # @return [void]
      def setup_bgp_link
        # complement local_ip attribute using layer3 info if possible
        # TODO: bgp-multihop case
        complement_local_ip_in_tps

        @network.nodes.each do |local_node|
          debug_print "# Target = local_node: #{local_node.name}"
          local_node.tps.each do |local_tp|
            local_ip, remote_ip = local_tp.attribute.fetch_values(:local_ip, :remote_ip)
            # cannot complement local_ip...it has external peer?
            next if local_ip.nil?

            debug_print "#   local tp/ip: #{local_tp.name}/#{local_ip} -> #{remote_ip}"
            remote_node, remote_tp = find_bgp_node_tp_by_ip_pair(remote_ip, local_ip)
            @network.link(*[local_node, local_tp, remote_node, remote_tp].map(&:name)) unless remote_tp.nil?
          end
        end
      end
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

      # rubocop:disable Metrics/MethodLength

      # @param [BgpPeerConfigurationTableRecord] peer_rec A peer configuration of the bgp node
      # @return [Hash] Attribute of bgp term-point
      def bgp_tp_attribute(peer_rec)
        {
          local_as: peer_rec.local_as,
          local_ip: peer_rec.local_ip,
          remote_as: peer_rec.remote_as,
          remote_ip: peer_rec.remote_ip,
          description: peer_rec.description,
          confederation: peer_rec.confederation,
          route_reflector_client: peer_rec.route_reflector_client,
          cluster_id: peer_rec.cluster_id,
          peer_group: peer_rec.peer_group,
          import_policies: reject_referred_policy(peer_rec.node, peer_rec.import_policy),
          export_policies: reject_referred_policy(peer_rec.node, peer_rec.export_policy)
        }
      end

      # @param [Array<CSVMapper::NamedStructuresTableRecord>] routing_policy_recs Named structure (routing-policy) recs
      # @param [String] policy_name BGP policy name
      # @return [Array] List of subroutines in named-structure data (BGP Routing_Policy data)
      def find_all_subroutines_from_policy(routing_policy_recs, policy_name)
        named_rec = routing_policy_recs.find { |r| r.structure_name == policy_name }
        return [] if named_rec.nil?

        policy_data = named_rec.structure_data
        policy_statements = policy_data['statements']
        # debug_print "#   - policy_data = #{JSON.pretty_generate(policy_statements)}"
        policy_statements.find_all { |s| s['guard']&.key?('subroutines') }
                         .map { |s| s['guard']['subroutines'] }
      end

      # @param [String] node Node name
      # @param [Array<String>] policies BGP policy names
      # @return [Array<String>] policies resolved inter-policy reference
      def reject_referred_policy(node, policies)
        debug_print "# node = #{node}, bgp-policies = #{policies}"
        routing_policy_recs = @named_structures.find_all_record_by_node_structure_type(node, 'Routing_Policy')
        return [] unless routing_policy_recs

        policy_ref_table = {}
        policies.each do |policy|
          subroutines = find_all_subroutines_from_policy(routing_policy_recs, policy)
          debug_print "#   - subroutines = #{subroutines}"
          subroutines.flatten.each do |sub|
            # table = callee : caller
            policy_ref_table[sub['calledPolicyName']] = policy
          end
          debug_print "#   - policy_ref_table: #{policy_ref_table}"
        end

        policies.reject { |policy| policy_ref_table.key?(policy) }
      end

      # rubocop:enable Metrics/MethodLength

      # @param [String] l3_node_name L3 node name to support
      # @param [String] ip_addr IP address
      # @return [Netomox::PseudoDSL::PTermPoint,nil] L3 term-point to support the bgp term-point
      # @raise [StandardError]
      def find_l3_tp_by_ip(l3_node_name, ip_addr)
        l3_node = @layer3p.node(l3_node_name)
        raise StandardError("Found unknown layer3 node name: #{l3_node_name}") if l3_node.nil?

        l3_node.tps.find do |l3_tp|
          debug_print "#     l3_tp: #{l3_tp.name}, #{l3_tp.attribute}"
          find_ip_in_l3_tp_includes(l3_tp, ip_addr)
        end
      end

      # @param [PNode] bgp_node BGP node (bgp proc)
      # @param [BgpPeerConfigurationTableRecord] peer_rec A peer configuration of the bgp node
      # @return [void]
      def add_bgp_tp(bgp_node, peer_rec)
        debug_print "#  peer: from #{peer_rec.local_ip} to #{peer_rec.remote_ip}"
        bgp_tp = bgp_node.term_point(peer_tp_name(peer_rec.remote_ip))
        bgp_tp.attribute = bgp_tp_attribute(peer_rec)
      end

      # @param [Netomox::PseudoDSL::PNode] bgp_node local bgp node
      # @param [Netomox::PseudoDSL::PTermPoint] bgp_tp Local bgp term-point
      # @param [String] local_ip Local ip address of the term-point
      # @return [void]
      def add_bgp_tp_support(bgp_node, bgp_tp, local_ip)
        support_l3_node = bgp_node.supports[0] # => ["layer3", "node-name"]
        l3_tp = find_l3_tp_by_ip(support_l3_node[1], local_ip)

        bgp_tp.attribute[:local_ip] = local_ip if bgp_tp.attribute[:local_ip].nil?
        bgp_tp.supports.push([*support_l3_node, l3_tp.name]) unless l3_tp.nil?
      end

      # @param [BgpProcessConfigurationTableRecord] proc_rec BGP process configuration
      # @return [Hash] BGP node (proc) attribute
      def bgp_node_attribute(proc_rec)
        {
          router_id: proc_rec.router_id,
          confederation_id: proc_rec.confederation_id,
          confederation_members: proc_rec.confederation_members,
          route_reflector: proc_rec.route_reflector
        }
      end
      # rubocop:disable Metrics/AbcSize

      # @param [BgpProcessConfigurationTableRecord] proc_rec A record of BGP process configuration
      # @return [String] Name of layer3 (underlay) node name
      def l3_node_name(proc_rec)
        proc_rec.grt? ? proc_rec.node : "#{proc_rec.node}_#{proc_rec.vrf}"
      end

      # @param [BgpProcessConfigurationTableRecord] proc_rec BGP process configuration
      # return [void]
      def add_bgp_node_tp(proc_rec)
        debug_print "# node: #{proc_rec.node} (vrf=#{proc_rec.vrf}), router_id=#{proc_rec.router_id}"
        bgp_node = @network.node(proc_rec.router_id)
        bgp_node.attribute = bgp_node_attribute(proc_rec)
        bgp_node.supports.push([@layer3p.name, l3_node_name(proc_rec)])

        # supporting node (NOTICE: vrf is not assumed)
        peer_recs = @bgp_peer_conf.find_all_recs_by_node_vrf(proc_rec.node, proc_rec.vrf)
        peer_recs.each { |peer_rec| add_bgp_tp(bgp_node, peer_rec) }
      end
      # rubocop:enable Metrics/AbcSize

      # @return [void]
      def setup_bgp_node_tp
        debug_print '# setup node/tp'
        # NOTE: Constructing this layer is based on bgp config (bgp topology), rather than L3 topology.
        @bgp_proc_conf.records.each { |rec| add_bgp_node_tp(rec) }
      end

      # @param [Netomox::PseudoDSL::PNode] bgp_node BGP node
      # @return [void]
      def update_confederation_id(bgp_node)
        debug_print '# update node confederation id'
        return unless bgp_node.attribute[:confederation_id].nil?

        confederation_ids = bgp_node.tps.map { |tp| tp.attribute[:confederation] }.uniq.compact
        debug_print "#  node: #{bgp_node.name}, confederation_ids: #{confederation_ids}"
        bgp_node.attribute[:confederation_id] = confederation_ids[0] unless confederation_ids.empty?
      end

      # @return [void]
      def update_bgp_attribute
        debug_print '# update bgp attribute'
        @network.nodes.each do |bgp_node|
          update_confederation_id(bgp_node)
        end
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
