# frozen_string_literal: true

require 'ipaddr'
require_relative 'pseudo_model'
require_relative 'csv_mapper/bgp_peer_conf_table'
require_relative 'csv_mapper/bgp_proc_conf_table'

module NetomoxExp
  module TopologyBuilder
    # rubocop:disable Metrics/ClassLength

    # BGP data builder
    class BgpDataBuilder < DataBuilderBase
      # @param [String] target Target network (config) data name
      # @param [Netomox::PseudoDSL::PNetwork] layer3p Layer3 network topology
      def initialize(target:, layer3p:, debug: false)
        super(debug:)
        @layer3p = layer3p
        @bgp_peer_conf = CSVMapper::BgpPeerConfigurationTable.new(target)
        @bgp_proc_conf = CSVMapper::BgpProcessConfigurationTable.new(target)
      end

      # @return [Netomox::PseudoDSL::PNetworks] Networks contains bgp topology
      def make_networks
        # setup bgp layer
        @network = @networks.network('bgp')
        @network.type = Netomox::NWTYPE_MDDO_BGP
        @network.attribute = { name: 'mddo-bgp-network' }
        # setup bgp layer
        setup_bgp_node_tp
        setup_bgp_link

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

      # @param [String] ip_str IP address string with prefix length ("a.b.c.d/nn")
      # @return [String] IP address string without prefix length
      def ip_str_wo_prefix(ip_str)
        ip_str.sub(%r{/\d+$}, '')
      end

      # @param [String] ip_addr IP address ("a.b.c.d") without prefix length ("/nn")
      def find_strict_match_ip_in_l3tp_attr(l3_tp, ip_addr)
        l3_tp.attribute[:ip_addrs].find do |ip|
          # layer3 ip addr format in :ip_addrs attr is "a.b.c.d/nn" (with prefix length)
          ip_str_wo_prefix(ip) == ip_addr && IPAddr.new(ip).include?(ip_addr)
        end
      end

      # @param [String] tp_ip IP address of a L3 term-point
      # @return [Array(Netomox::PseudoDSL::PNode, Netomox::PseudoDSL::PTermPoint), Array(nil, nil)]
      #   A pair of node and term-point that have the IP address
      def find_l3_node_tp_by_ip(tp_ip)
        @layer3p.nodes.reject { |node| node.attribute[:node_type] == 'segment' }.each do |node|
          tp = node.tps.find { |term_point| find_strict_match_ip_in_l3tp_attr(term_point, tp_ip) }
          next if tp.nil?

          return [node, tp]
        end
        [nil, nil]
      end

      # rubocop:disable Metrics/AbcSize

      # @param [Netomox::PseudoDSL::PNode] bgp_local_node Local node (BGP)
      # @param [Netomox::PseudoDSL::PNode] l3_remote_node Remote node (L3)
      # @param [Netomox::PseudoDSL::PTermPoint] l3_remote_tp Remote term-point (L3)
      # @return [Netomox::PseudoDSL::PTermPoint, nil] Local term-point
      def l3_local_tp_by_remote(bgp_local_node, l3_remote_node, l3_remote_tp)
        l3_local_node = @layer3p.node(bgp_local_node.supports[0][1])
        debug_print "#   - l3_local: #{l3_local_node.name}, l3_remote: #{l3_remote_node.name}[#{l3_remote_tp.name}]"
        l3_remote_dst_edge = @layer3p.find_link_by_src_name(l3_remote_node.name, l3_remote_tp.name)&.dst
        debug_print "#   - l3_remote_dst: #{l3_remote_dst_edge}"
        # NOTE: No eBGP multi-hop assumed,
        #   it finds the `local-node -- segment -- remote-node` relation in layer3
        l3_local_link = @layer3p.find_all_links_by_src_name(l3_local_node.name)
                                .find { |link| link.dst.node == l3_remote_dst_edge.node }
        debug_print "#   - l3_local_link: #{l3_local_link}"
        _, l3_local_tp = @layer3p.find_node_tp_by_edge(l3_local_link.src)
        l3_local_tp
      end
      # rubocop:enable Metrics/AbcSize

      # @param [Netomox::PseudoDSL::PTermPoint] l3_local_tp L3 Local term-point
      # @param [String] remote_ip Peer IP address
      # @return [String, nil] Local ip address (companion of remote_ip)
      def l3_local_ip_by_remote_ip(l3_local_tp, remote_ip)
        debug_print "#   - l3_local_tp: #{l3_local_tp.name}, attr: #{l3_local_tp.attribute}"
        l3_local_ip = l3_local_tp.attribute[:ip_addrs].find { |ip| IPAddr.new(ip).include?(remote_ip) }
        l3_local_ip.nil? ? nil : ip_str_wo_prefix(l3_local_ip)
      end

      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize

      # @return [void]
      def complement_local_ip_in_tps
        debug_print '# complement_local_ip_in_tps'
        @network.nodes.each do |bgp_local_node|
          debug_print "# Target = local_node: #{bgp_local_node.name}"
          bgp_local_node.tps.each do |bgp_local_tp|
            local_ip = bgp_local_tp.attribute[:local_ip]
            debug_print "#   Target = local_tp: #{bgp_local_tp.name}, local_ip: #{local_ip}"
            # Nothing to do if bgp_local_tp have local_ip attribute
            next unless local_ip.nil?

            remote_ip = bgp_local_tp.attribute[:remote_ip]
            debug_print "#   - remote_ip: #{remote_ip}"
            l3_remote_node, l3_remote_tp = find_l3_node_tp_by_ip(remote_ip)
            next if l3_remote_node.nil? || l3_remote_tp.nil?

            l3_local_tp = l3_local_tp_by_remote(bgp_local_node, l3_remote_node, l3_remote_tp)
            next if l3_local_tp.nil?

            local_ip = l3_local_ip_by_remote_ip(l3_local_tp, remote_ip)
            bgp_local_tp.attribute[:local_ip] = local_ip
            debug_print "#   - bgp_local_tp: attr: #{bgp_local_tp.attribute}"
          end
        end
      end
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize

      # @return [void]
      def setup_bgp_link
        # complement local_ip attribute using layer3 info if possible
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
          confederation: peer_rec.confederation,
          route_reflector_client: peer_rec.route_reflector_client,
          cluster_id: peer_rec.cluster_id,
          peer_group: peer_rec.peer_group,
          import_policies: peer_rec.import_policy,
          export_policies: peer_rec.export_policy
        }
      end

      # rubocop:enable Metrics/MethodLength

      # @param [String] l3_node_name L3 node name to support
      # @param [String] local_ip Local ip address of a bgp term-point (peer)
      # @return [PTermPoint] L3 term-point to support the bgp term-point
      # @raise [StandardError]
      def find_support_l3_tp(l3_node_name, local_ip)
        l3_node = @layer3p.node(l3_node_name)
        raise StandardError("Found unknown layer3 node name: #{l3_node_name}") if l3_node.nil?

        l3_node.tps.find do |l3_tp|
          debug_print "#    l3_tp: #{l3_tp.name}, #{l3_tp.attribute}"
          l3_tp.attribute[:ip_addrs] # ["a.b.c.d/nn",...]
               .map { |ip| IPAddr.new(ip).include?(local_ip) }
               .include?(true)
        end
      end

      # rubocop:disable Metrics/AbcSize

      # @param [PNode] bgp_node BGP node (bgp proc)
      # @param [BgpPeerConfigurationTableRecord] peer_rec A peer configuration of the bgp node
      # @return [void]
      def add_bgp_tp(bgp_node, peer_rec)
        debug_print "#  peer: from #{peer_rec.local_ip} to #{peer_rec.remote_ip}"
        bgp_tp = bgp_node.term_point(peer_tp_name(peer_rec.remote_ip))
        bgp_tp.attribute = bgp_tp_attribute(peer_rec)

        node_support = bgp_node.supports[0] # ["layer3", "L3-node-name"]
        debug_print "#  node support: #{node_support}"
        l3_tp = find_support_l3_tp(node_support[1], peer_rec.local_ip)
        # TODO: complement eBGP peer
        bgp_tp.supports.push([*node_support, l3_tp.name]) unless l3_tp.nil?
      end
      # rubocop:enable Metrics/AbcSize

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

      # @param [BgpProcessConfigurationTableRecord] proc_rec BGP process configuration
      # return [void]
      def add_bgp_node_tp(proc_rec)
        debug_print "# node: #{proc_rec.node} (vrf=#{proc_rec.vrf}), router_id=#{proc_rec.router_id}"
        bgp_node = @network.node(proc_rec.router_id)
        bgp_node.attribute = bgp_node_attribute(proc_rec)
        bgp_node.supports.push([@layer3p.name, proc_rec.node])

        # supporting node (NOTICE: vrf is not assumed)
        peer_recs = @bgp_peer_conf.find_all_recs_by_node_vrf(proc_rec.node, proc_rec.vrf)
        peer_recs.each { |peer_rec| add_bgp_tp(bgp_node, peer_rec) }
      end
      # rubocop:enable Metrics/AbcSize

      # @return [void]
      def setup_bgp_node_tp
        debug_print '# setup node/tp'
        @bgp_proc_conf.records.each { |rec| add_bgp_node_tp(rec) }
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
