# frozen_string_literal: true

require 'netomox'

require_relative 'bgp_proc_data_builder'

module NetomoxExp
  module UsecaseDeliverer
    # rubocop:disable Metrics/ClassLength

    # bgp_as network data builder
    class BgpAsDataBuilder
      # @param [String] usecase Usecase name
      # @param [Hash] usecase_params Params data
      # @param [Array<Hash>] usecase_flows Flow data
      # @param [Netomox::Topology::Networks] int_as_topology Internal AS topology (original_asis)
      def initialize(usecase, usecase_params, usecase_flows, int_as_topology)
        # each external-AS topology which contains layer3/bgp_proc layer
        @src_topo_builders = src_topo_builders(usecase, usecase_params, usecase_flows, int_as_topology)
        @dst_topo_builder = dst_topo_builder(usecase, usecase_params, usecase_flows, int_as_topology)

        # target external-AS topology (empty)
        # src/dst ext-AS topology (layer3/bgp-proc) are merged into it with a new layer, bgp_as.
        @ext_as_topology = Netomox::PseudoDSL::PNetworks.new
        # internal-AS topology data (Netomox::Topology::Networks)
        @int_as_topology = int_as_topology

        # bgp_as network
        @bgp_as_nw = @ext_as_topology.network('bgp_as')
        @bgp_as_nw.type = Netomox::NWTYPE_MDDO_BGP_AS
        @bgp_as_nw.attribute = { name: 'mddo-bgp-as-network' }
      end

      # @return [Hash] External-AS topology data (rfc8345)
      def build_topology
        merge_ext_topologies!([*@src_topo_builders, @dst_topo_builder].map(&:ext_as_topology))
        make_bgp_as_topology!

        @ext_as_topology.interpret.topo_data
      end

      private

      # @param [String] usecase Usecase name
      # @param [Hash] usecase_params Params data
      # @param [Array<Hash>] usecase_flows Flow data
      # @param [Netomox::Topology::Networks] int_as_topology Internal AS topology (original_asis)
      # @return [Array<BgpProcDataBuilder>]
      # @raise [StandardError]
      def src_topo_builders(usecase, usecase_params, usecase_flows, int_as_topology)
        if usecase_params.key?('source_as')
          [BgpProcDataBuilder.new(usecase, :source_as, usecase_params['source_as'], usecase_flows, int_as_topology, 0)]
        elsif usecase_params.key?('source_ases')
          usecase_params['source_ases'].map.with_index do |src_as_param, ipam_seed|
            BgpProcDataBuilder.new(usecase, :source_as, src_as_param, usecase_flows, int_as_topology, ipam_seed)
          end
        else
          raise StandardError, 'Invalid usecase params: source-as params are not found'
        end
      end

      # @param [Hash] usecase_params Params data
      # @return [Integer] IPAM seed for destination AS
      # @raise [StandardError]
      def dst_ipam_seed(usecase_params)
        if usecase_params.key?('source_as')
          1 # source_as = 0, dest_as = 1
        elsif usecase_params.key?('source_ases')
          usecase_params['source_ases'].length # source_as = 0...length-1, dest_as = length
        else
          raise StandardError, 'Invalid usecase params: source-as params are not found'
        end
      end

      # @param [String] usecase Usecase name
      # @param [Hash] usecase_params Params data
      # @param [Array<Hash>] usecase_flows Flow data
      # @param [Netomox::Topology::Networks] int_as_topology Internal AS topology (original_asis)
      # @return [BgpProcDataBuilder] Builder for destination AS
      def dst_topo_builder(usecase, usecase_params, usecase_flows, int_as_topology)
        ipam_seed = dst_ipam_seed(usecase_params)
        BgpProcDataBuilder.new(usecase, :dest_as, usecase_params['dest_as'], usecase_flows, int_as_topology, ipam_seed)
      end

      # @param [Array<Netomox::PseudoDSL::PNetworks>] src_ext_as_topologies Src/Dst Ext-AS topologies (layer3/bgp-proc)
      # @return [void]
      def merge_ext_topologies!(src_ext_as_topologies)
        # merge
        %w[bgp_proc layer3].each do |layer|
          src_ext_as_topologies.each do |src_ext_as_topology|
            src_network = src_ext_as_topology.network(layer)
            dst_network = @ext_as_topology.network(layer)

            dst_network.type = src_network.type
            dst_network.attribute = src_network.attribute

            dst_network.nodes.append(*src_network.nodes)
            dst_network.links.append(*src_network.links)
          end
        end
      end

      # @return [Netomox::PseudoDSL::PNode] Added internal-AS bgp-as node
      def add_int_bgp_as_node
        # int_as is common for each ext-as builder, represented as head
        int_asn = @src_topo_builders[0].as_state[:int_asn]
        int_bgp_as_node = @bgp_as_nw.node("as#{int_asn}")
        int_bgp_as_node.attribute = { as_number: int_asn }
        int_bgp_proc_nw = @int_as_topology.find_network('bgp_proc')
        int_bgp_as_node.supports = int_bgp_proc_nw.nodes.map { |node| ['bgp_proc', node.name] }
        int_bgp_as_node
      end

      # @return [Array<Integer>] External-AS number list (src/dst asn)
      def ext_asn_list
        [*@src_topo_builders.map { |s| s.as_state[:ext_asn] }, @dst_topo_builder.as_state[:ext_asn]].map(&:to_i)
      end

      # @param [Integer] ext_asn External-AS number
      # @param [Array<Netomox::PseudoDSL::PNode>] support_bgp_proc_nodes Underlay(bgp-proc) nodes in the ASN
      # @return [Netomox::PseudoDSL::PNode] Added external-AS bgp-as node
      def add_ext_bgp_as_node(ext_asn, support_bgp_proc_nodes)
        ext_bgp_as_node = @bgp_as_nw.node("as#{ext_asn}")
        ext_bgp_as_node.attribute = { as_number: ext_asn }
        ext_bgp_as_node.supports = support_bgp_proc_nodes.map { |node| ['bgp_proc', node.name] }
        ext_bgp_as_node
      end

      # @param [Netomox::PseudoDSL::PTermPoint] ext_bgp_proc_tp External-AS bgp-proc term-point
      # @return [String, nil] ebgp-peer flag if found
      def find_bgp_proc_tp_ebgp_flag(ext_bgp_proc_tp)
        ext_bgp_proc_tp.attribute[:flags].find { |f| f =~ /^ebgp-peer=.+$/ }
      end

      # @param [Netomox::PseudoDSL::PTermPoint] ext_bgp_proc_tp External-AS bgp-proc term-point
      # @return [Boolean] true if the term-point is eBGP peer
      def ebgp_peer_bgp_proc_tp?(ext_bgp_proc_tp)
        ext_bgp_proc_tp.attribute.key?(:flags) && !find_bgp_proc_tp_ebgp_flag(ext_bgp_proc_tp).nil?
      end

      # extract peer node/tp name from ebgp-peer flag (string)
      # @param [Netomox::PseudoDSL::PTermPoint] ext_bgp_proc_tp External-AS bgp-proc term-point
      # @return [Array(String, String)] peer node/tp name
      def peer_int_node_tp(ext_bgp_proc_tp)
        peer_flag = find_bgp_proc_tp_ebgp_flag(ext_bgp_proc_tp)
        match = peer_flag.split('=')[-1].match(/(?<node>.+)\[(?<tp>.+)\]/)

        [match[:node], match[:tp]]
      end

      # add link bidirectional
      # @param [Netomox::PseudoDSL::PNode] node1
      # @param [Netomox::PseudoDSL::PTermPoint] tp1
      # @param [Netomox::PseudoDSL::PNode] node2
      # @param [Netomox::PseudoDSL::PTermPoint] tp2
      # @return [void]
      def add_bgp_as_bdlink(node1, tp1, node2, tp2)
        @bgp_as_nw.link(node1.name, tp1.name, node2.name, tp2.name)
        @bgp_as_nw.link(node2.name, tp2.name, node1.name, tp1.name)
      end

      # @param [Netomox::PseudoDSL::PNode] ext_bgp_as_node External-AS bgp-as node (target)
      # @param [Netomox::PseudoDSL::PNode] ext_bgp_proc_node External-AS bgp-proc node (underlay node)
      # @param [Netomox::PseudoDSL::PTermPoint] ext_bgp_proc_tp External-AS bgp-proc term-point (underlay tp)
      # @return [Array(Netomox::PseudoDSL::PNode, Netomox::PseudoDSL::PTermPoint)] Added node/tp
      def add_ext_bgp_as_tp(ext_bgp_as_node, ext_bgp_proc_node, ext_bgp_proc_tp)
        ext_bgp_as_tp = ext_bgp_as_node.term_point(ext_bgp_proc_tp.name)
        ext_bgp_as_tp.supports.push(['bgp_proc', ext_bgp_proc_node.name, ext_bgp_proc_tp.name])

        [ext_bgp_as_node, ext_bgp_as_tp]
      end

      # @param [Netomox::PseudoDSL::PNode] int_bgp_as_node Internal-AS bgp-as node (target)
      # @param [Netomox::PseudoDSL::PTermPoint] ext_bgp_proc_tp External-AS bgp-proc term-point (underlay tp)
      # @return [Array(Netomox::PseudoDSL::PNode, Netomox::PseudoDSL::PTermPoint)] Added node/tp
      def add_int_bgp_as_tp(int_bgp_as_node, ext_bgp_proc_tp)
        peer_int_node, peer_int_tp = peer_int_node_tp(ext_bgp_proc_tp)
        int_bgp_as_tp = int_bgp_as_node.term_point(peer_int_tp)
        int_bgp_as_tp.supports.push(['bgp_proc', peer_int_node, peer_int_tp])

        [int_bgp_as_node, int_bgp_as_tp]
      end

      # @param [Netomox::PseudoDSL::PNode] int_bgp_as_node Internal-AS bgp-as node
      # @param [Netomox::PseudoDSL::PNode] ext_bgp_as_node External-AS bgp-as node
      # @param [Array<Netomox::PseudoDSL::PNode>] support_bgp_proc_nodes Underlay(bgp-proc) nodes in the ASN
      # @return [void]
      def add_ext_bgp_link_tp(int_bgp_as_node, ext_bgp_as_node, support_bgp_proc_nodes)
        # inter-as-node (inter-AS) links
        # (no links between ext-ext, there are only ext-int links)
        support_bgp_proc_nodes.each do |ext_bgp_proc_node|
          ext_bgp_proc_node.tps.each do |ext_bgp_proc_tp|
            next unless ebgp_peer_bgp_proc_tp?(ext_bgp_proc_tp)

            # term-point
            _, ext_bgp_as_tp = add_ext_bgp_as_tp(ext_bgp_as_node, ext_bgp_proc_node, ext_bgp_proc_tp)
            _, int_bgp_as_tp = add_int_bgp_as_tp(int_bgp_as_node, ext_bgp_proc_tp)

            # link (bidirectional)
            add_bgp_as_bdlink(int_bgp_as_node, int_bgp_as_tp, ext_bgp_as_node, ext_bgp_as_tp)
          end
        end
      end

      # @return [void]
      def make_bgp_as_topology!
        # internal-AS node
        int_bgp_as_node = add_int_bgp_as_node

        # external-AS node
        ext_bgp_proc_nw = @ext_as_topology.network('bgp_proc')
        ext_asn_list.each do |ext_asn|
          support_bgp_proc_nodes = ext_bgp_proc_nw.nodes.filter { |node| node.tps[0].attribute[:local_as] == ext_asn }
          ext_bgp_as_node = add_ext_bgp_as_node(ext_asn, support_bgp_proc_nodes)
          add_ext_bgp_link_tp(int_bgp_as_node, ext_bgp_as_node, support_bgp_proc_nodes)
        end
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
