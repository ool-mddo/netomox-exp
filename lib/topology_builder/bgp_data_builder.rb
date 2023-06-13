# frozen_string_literal: true

require_relative 'pseudo_model'
require_relative 'csv_mapper/bgp_peer_conf_table'
require_relative 'csv_mapper/bgp_proc_conf_table'

module NetomoxExp
  module TopologyBuilder
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

      # @return [Netomox::PseudoDSL::PNetworks] Networks contains ospf area topology
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
      # @return [Array(PNode, PTermPoint), Array(nil, nil)] A pair of node and term-point = source of the link
      def find_node_and_tp_by_ip(local_ip, remote_ip)
        @network.nodes.each do |node|
          tp = node.tps.find do |term_point|
            term_point.attribute[:local_ip] == local_ip && term_point.attribute[:remote_ip] == remote_ip
          end
          next if tp.nil?

          return [node, tp]
        end
        [nil, nil]
      end

      # @return [void]
      def setup_bgp_link
        @network.nodes.each do |local_node|
          debug_print "# Target = local_node: #{local_node.name}"
          local_node.tps.each do |local_tp|
            local_ip = local_tp.attribute[:local_ip]
            remote_ip = local_tp.attribute[:remote_ip]
            remote_node, remote_tp = find_node_and_tp_by_ip(remote_ip, local_ip)
            @network.link(*[local_node, local_tp, remote_node, remote_tp].map(&:name)) unless remote_node.nil?
          end
        end
      end

      # @param [PNode] bgp_node BGP node (bgp proc)
      # @param [BgpPeerConfigurationTableRecord] peer_rec A peer configuration of the bgp node
      # @return [void]
      def add_bgp_tp(bgp_node, peer_rec)
        debug_print "#  peer: from #{peer_rec.local_ip} to #{peer_rec.remote_ip}"
        bgp_tp = bgp_node.term_point(peer_tp_name(peer_rec.remote_ip))
        bgp_tp.attribute = {
          local_as: peer_rec.local_as,
          local_ip: peer_rec.local_ip,
          remote_as: peer_rec.remote_as,
          remote_ip: peer_rec.remote_ip
        }
      end

      # @param [BgpProcessConfigurationTableRecord] proc_rec BGP process configuration
      # return [void]
      def add_bgp_node_tp(proc_rec)
        debug_print "# node: #{proc_rec.node} (vrf=#{proc_rec.vrf}), router_id=#{proc_rec.router_id}"
        bgp_node = @network.node(proc_rec.router_id)
        bgp_node.attribute = { router_id: proc_rec.router_id }

        peer_recs = @bgp_peer_conf.find_all_recs_by_node_vrf(proc_rec.node, proc_rec.vrf)
        peer_recs.each { |peer_rec| add_bgp_tp(bgp_node, peer_rec) }
      end

      # @return [void]
      def setup_bgp_node_tp
        debug_print '# setup node/tp'
        @bgp_proc_conf.records.each { |rec| add_bgp_node_tp(rec) }
      end
    end
  end
end
