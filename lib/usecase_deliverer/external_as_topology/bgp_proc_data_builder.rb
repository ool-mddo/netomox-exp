# frozen_string_literal: true

require 'netomox'

require_relative 'p_network'
require_relative 'layer3_data_builder'
require_relative 'bgp_proc_data_builder_routers'
require_relative 'bgp_proc_data_builder_ibgp_links'

module NetomoxExp
  module UsecaseDeliverer
    # bgp_proc network data builder
    class BgpProcDataBuilder < Layer3DataBuilder
      # @!attribute [r] ext_as_topology External-AS topology, contains bgp-proc/layer3
      #   @return [Netomox::PseudoDSL::PNetworks]
      # @!attribute [r] bgp_proc_nw (for debugging)
      #   @return [Netomox::PseudoDSL::PNetwork]
      attr_reader :ext_as_topology, :bgp_proc_nw

      # external-AS bgp node default policies
      # advertise all prefixes
      POLICY_ADV_ALL_PREFIXES = {
        name: 'advertise-all-prefixes',
        statements: [
          { name: 10, conditions: [{ rib: 'inet.0' }], actions: [{ target: 'accept' }] }
        ]
      }.freeze
      # all routes
      POLICY_PASS_ALL = {
        name: 'pass-all',
        default: { actions: [{ target: 'accept' }] }
      }.freeze
      # high-priority routes with local-preference 200
      POLICY_PASS_ALL_LP200 = {
        name: 'pass-all-lp200',
        default: { actions: [{ local_preference: 200 }, { target: 'accept' }] }
      }.freeze
      # default policies to set external-as node
      DEFAULT_POLICIES = [POLICY_ADV_ALL_PREFIXES, POLICY_PASS_ALL, POLICY_PASS_ALL_LP200].freeze

      # @param [String] usecase Usecase name
      # @param [Symbol] as_type (enum: [source_as, :dest_as])
      # @param [Hash] as_params AS params data
      # @param [Array<Hash>] usecase_flows Flow data
      # @param [Netomox::Topology::Networks] int_as_topology Internal AS topology (original_asis)
      # @param [Integer] ipam_seed Seed number (index) for ipam
      def initialize(usecase, as_type, as_params, usecase_flows, int_as_topology, ipam_seed)
        super

        # bgp_proc network
        @bgp_proc_nw = @ext_as_topology.network('bgp_proc')
        @bgp_proc_nw.type = Netomox::NWTYPE_MDDO_BGP_PROC
        @bgp_proc_nw.attribute = { name: 'mddo-bgp-network' }
        @bgp_proc_nw.supports.push(@layer3_nw.name)

        make_bgp_proc_topology!
      end

      private

      # @param [Netomox::PseudoDSL::PTermPoint] layer3_tp
      # @return [String] IP address
      def layer3_tp_addr_str(layer3_tp)
        layer3_tp.attribute[:ip_addrs][0].sub(%r{/\d+$}, '')
      end

      # @param [Netomox::PseudoDSL::PNode] bgp_proc_core_node Core of external-AS
      # @return [Array<Array(Hash, Hash)>] peer_list pair to connected ibgp (full-mesh)
      def bgp_proc_ibgp_router_pairs(bgp_proc_core_node)
        @peer_list.map { |peer_item| peer_item[:bgp_proc] }
                  .append({ node_name: bgp_proc_core_node.name, node: bgp_proc_core_node })
                  .concat(find_all_bgp_proc_ebgp_candidate_routers.map { |node| { node_name: node.name, node: } })
                  .combination(2)
                  .to_a
      end

      # @param [Netomox::PseudoDSL::PNode] bgp_proc_core_node Core of external-AS
      # @param [Array<Netomox::PseudoDSL::PNode>] bgp_proc_rcore_nodes Region-core list of external-AS
      # @return [Array<Array(Hash, Hash)>] peer_list pair to connected ibgp (full-mesh)
      def bgp_proc_ibgp_rr_pairs(bgp_proc_core_node, bgp_proc_rcore_nodes)
        core_hash = { node_name: bgp_proc_core_node.name, node: bgp_proc_core_node }
        find_all_bgp_proc_ebgp_routers
          .concat(find_all_bgp_proc_ebgp_candidate_routers)
          .concat(bgp_proc_rcore_nodes)
          .map { |node| { node_name: node.name, node: } }
          .map { |node_hash| [core_hash, node_hash] }
      end

      # @param [Netomox::PseudoDSL::PNode] bgp_proc_core_node
      # @return [void]
      def make_bgp_proc_topology_region_as(bgp_proc_core_node)
        # add region-core node
        bgp_proc_rcore_nodes = find_all_layer3_region_core_routers.map do |router|
          add_bgp_proc_region_core_router(router)
        end
        # iBGP (RR) links: hub=core00, spoke=ebgp+region-core nodes
        bgp_proc_ibgp_rr_pairs(bgp_proc_core_node, bgp_proc_rcore_nodes).each do |peer_item_bgp_proc_pair|
          add_bgp_proc_ibgp_links(peer_item_bgp_proc_pair)
        end
      end

      # @param [Netomox::PseudoDSL::PNode] bgp_proc_core_node
      # @return [void]
      def make_bgp_proc_topology_simple_as(bgp_proc_core_node)
        # iBGP mesh
        # router [] -- [tp1] Seg_x.x.x.x [tp2] -- [] router
        bgp_proc_ibgp_router_pairs(bgp_proc_core_node).each do |peer_item_bgp_proc_pair|
          add_bgp_proc_ibgp_links(peer_item_bgp_proc_pair)
        end
      end

      # @return [void]
      def make_bgp_proc_topology!
        # add core (aggregation) router
        # NOTE: assign 1st router-id for core router
        bgp_proc_core_node = add_bgp_proc_core_router
        # add edge-router (ebgp speaker and inter-AS links)
        @peer_list.each { |peer_item| add_bgp_proc_ebgp_router(peer_item) }
        # add edge-candidate-router (NOT ebgp speaker yet, but will be ebgp speaker)
        find_all_layer3_ebgp_candidate_routers.each do |router|
          add_bgp_proc_ebgp_candidate_router(router)
        end

        if region_as_params?
          make_bgp_proc_topology_region_as(bgp_proc_core_node)
        else
          make_bgp_proc_topology_simple_as(bgp_proc_core_node)
        end
      end
    end
  end
end
