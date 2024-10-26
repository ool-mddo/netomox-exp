# frozen_string_literal: true

require 'ipaddr'
require 'netomox'

require_relative 'tiny_ipam'
require_relative 'int_as_data_builder'
require_relative 'layer3_data_builder_routers'
require_relative 'layer3_data_builder_ibgp_links'
require_relative 'layer3_data_builder_endpoint'

module NetomoxExp
  module UsecaseDeliverer
    # rubocop:disable Metrics/ClassLength

    # Layer3 network data builder
    class Layer3DataBuilder < IntAsDataBuilder
      # @!attribute [r] layer3_nw (for debugging)
      #   @return [Netomox::PseudoDSL::PNetworks]
      attr_reader :layer3_nw

      # rubocop:disable Metrics/ParameterLists

      # @param [String] usecase Usecase name
      # @param [Symbol] as_type (enum: [:source_as, :dest_as])
      # @param [Hash] as_params AS params data
      # @param [Array<Hash>] usecase_flows Flow data
      # @param [Netomox::Topology::Networks] int_as_topology Internal AS topology (original_asis)
      # @param [Integer] ipam_seed Seed number (index) for ipam
      def initialize(usecase, as_type, as_params, usecase_flows, int_as_topology, ipam_seed)
        super(usecase, as_type, as_params, int_as_topology)

        # list endpoint (iperf-node) info from flow data
        @flow_prefixes = column_items_from_flows(usecase_flows)
        # assign base prefix to ipam
        ipam_assign_base_prefix(ipam_seed)
        # target external-AS topology (empty)
        @ext_as_topology = Netomox::PseudoDSL::PNetworks.new
        # layer3 network
        @layer3_nw = @ext_as_topology.network('layer3')
        @layer3_nw.type = Netomox::NWTYPE_MDDO_L3
        @layer3_nw.attribute = { name: 'mddo-layer3-network' }

        make_layer3_topology!
      end
      # rubocop:enable Metrics/ParameterLists

      private

      # @param [Integer] ipam_seed Seed number (index) for ipam
      # @return [void]
      def ipam_assign_base_prefix(ipam_seed)
        ipam = TinyIPAM.instance # singleton
        # NOTE: 'subnet' key is optional in source/dest-as parameters.
        #   default: 169.254.[0,2,4,...].0/23
        base_prefix = @params['subnet'] || "169.254.#{ipam_seed * 2}.0/23"
        ipam.assign_base_prefix(base_prefix)
      end

      # @yield Operations using same link address
      # @yieldparam [String] current_link_ip_str Current link (segment) ip address
      # @yieldparam [Array(String, String)] current_link_intf_ip_str_pair Interface ip address pair of the link
      # @yieldreturn [void]
      # @return [void]
      def ipam_link_scope
        ipam = TinyIPAM.instance # singleton
        yield(ipam.current_link_ip_str, ipam.current_link_intf_ip_str_pair) if block_given?
        # next link-ip
        ipam.count_link
      end

      # @yield Operations using same loopback address
      # @yieldparam [String] current_loopback_ip_str Current loopback ip address
      # @yieldreturn [void]
      # @return [void]
      def ipam_loopback_scope
        ipam = TinyIPAM.instance # singleton
        yield(ipam.current_loopback_ip_str) if block_given?
        # next loopback-ip
        ipam.count_loopback
      end

      # add link bidirectional
      # @param [Netomox::Topology::Node, Netomox::PseudoDSL::PNode] node1
      # @param [Netomox::Topology::TermPoint, Netomox::PseudoDSL::PTermPoint] tp1
      # @param [Netomox::Topology::Node, Netomox::PseudoDSL::PNode] node2
      # @param [Netomox::Topology::TermPoint, Netomox::PseudoDSL::PTermPoint] tp2
      # @return [void]
      def add_layer3_bdlink(node1, tp1, node2, tp2)
        @layer3_nw.link(node1.name, tp1.name, node2.name, tp2.name)
        @layer3_nw.link(node2.name, tp2.name, node1.name, tp1.name)
      end

      # @param [Netomox::PseudoDSL::PNode] layer3_core_node Core of external-AS
      # @return [Array<Array(Hash, Hash)>] peer_list pair to connected ibgp (full-mesh)
      def layer3_ibgp_router_pairs(layer3_core_node)
        @peer_list.map { |peer_item| peer_item[:layer3] }
                  .append({ node_name: layer3_core_node.name, node: layer3_core_node })
                  .concat(find_all_layer3_ebgp_candidate_routers.map { |node| { node_name: node.name, node: } })
                  .combination(2)
                  .to_a
      end

      # @param [Netomox::PseudoDSL::PNode] layer3_core_node Layer3 core node
      # @return [void]
      def make_layer3_topology_simple_as(layer3_core_node)
        # iBGP mesh
        # router [] -- [tp1] Seg_x.x.x.x [tp2] -- [] router
        layer3_ibgp_router_pairs(layer3_core_node).each do |peer_item_l3_pair|
          add_layer3_ibgp_links(peer_item_l3_pair)
        end

        # endpoint = iperf node
        # endpoint [] -- [tp1] Seg_y.y.y.y [tp2] -- [] core
        @flow_prefixes.each_with_index do |flow_prefix, flow_index|
          add_layer3_core_to_endpoint_links(layer3_core_node, flow_prefix, flow_index)
        end
      end

      # @return [Array<Netomox::PseudoDSL::PNode>] layer3 region core router nodes
      def add_layer3_region_core_routers
        @params['regions'].map.with_index do |region, index|
          # node
          layer3_rcore_node = @layer3_nw.node(layer3_router_name(format('core%02d', index + 1)))
          layer3_rcore_node.attribute = {
            node_type: 'node',
            flags: %W[region-core-router region=#{region['region']}]
          }
          # term-point (loopback)
          add_loopback_to_layer3_node(layer3_rcore_node)

          layer3_rcore_node
        end
      end

      # @param [Netomox::PseudoDSL::PNode] layer3_core_node Layer3 core node
      # @param [Array<Netomox::PseudoDSL::PNode>] layer3_rcore_nodes Layer3 region core nodes
      # @return [Array<Array(Hash, Hash)>] pair to connected ibgp (RR hub-spoke)
      def layer3_ibgp_rr_pairs(layer3_core_node, layer3_rcore_nodes)
        core_hash = { node_name: layer3_core_node.name, node: layer3_core_node }
        find_all_layer3_ebgp_routers
          .concat(find_all_layer3_ebgp_candidate_routers)
          .concat(layer3_rcore_nodes)
          .map { |node| { node_name: node.name, node: } }
          .map { |node_hash| [core_hash, node_hash] }
      end

      # @param [Netomox::PseudoDSL::PNode] layer3_rcore_node Layer3 region core node
      # @return [Hash] region params of the region-core node
      def params_by_rcore(layer3_rcore_node)
        region_attr = layer3_rcore_node.attribute[:flags].find { |flag| flag =~ /region=.+/ }
        region_str = region_attr.split('=').last
        @params['regions'].find { |region| region['region'] == region_str }
      end

      # @param [Netomox::PseudoDSL::PNode] layer3_rcore_node Layer3 region core node
      # @param [String] flow_prefix Flow prefix (e.g. a.b.c.d/xx)
      # @return [Boolean] true if the region core node has the flow prefix
      def prefix_under_rcore?(layer3_rcore_node, flow_prefix)
        flow_prefix_obj = IPAddr.new(flow_prefix)
        region_params = params_by_rcore(layer3_rcore_node)
        region_params['prefixes'].map { |prefix| IPAddr.new(prefix) }.any? do |region_prefix_obj|
          region_prefix_obj.include?(flow_prefix_obj) || flow_prefix_obj.include?(region_prefix_obj)
        end
      end

      # @param [String] flow_prefix Flow prefix (e.g. a.b.c.d/xx)
      # @return [nil, Netomox::PseudoDSL::PNode]
      def find_rcore_by_flow_prefix(flow_prefix)
        find_all_layer3_region_core_routers.find do |layer3_rcore_node|
          prefix_under_rcore?(layer3_rcore_node, flow_prefix)
        end
      end

      # rubocop:disable Metrics/MethodLength

      # @param [Netomox::PseudoDSL::PNode] layer3_core_node Layer3 core node
      # @return [void]
      def make_layer3_topology_region_as(layer3_core_node)
        # Add region core node
        layer3_rcore_nodes = add_layer3_region_core_routers
        # iBGP (RR) links: hub=core00, spoke=ebgp+region-core nodes
        layer3_ibgp_rr_pairs(layer3_core_node, layer3_rcore_nodes).each do |peer_item_l3_pair|
          add_layer3_ibgp_links(peer_item_l3_pair)
        end

        # endpoint = iperf node
        # endpoint [] -- [] Seg [] -- [] region-core
        ep_index = 0
        @flow_prefixes.each do |flow_prefix|
          # target region core
          layer3_rcore_node = find_rcore_by_flow_prefix(flow_prefix)
          if layer3_rcore_node.nil?
            NetomoxExp.logger.error "Flow prefix: #{flow_prefix} not found in regions (usecase params mismatch)"
            next
          end

          add_layer3_core_to_endpoint_links(layer3_rcore_node, flow_prefix, ep_index)
          ep_index += 1
        end
      end
      # rubocop:enable Metrics/MethodLength

      # @return [void]
      def make_layer3_topology!
        # add core (aggregation) router
        layer3_core_node = add_layer3_core_router
        # add edge-router (ebgp speaker and inter-AS links)
        @peer_list.each_with_index { |peer_item, peer_index| add_layer3_edge_router(peer_item, peer_index) }
        # add edge-candidate-router (NOT ebgp speaker yet, but will be ebgp speaker)
        @params['add_links']&.each { |add_link| add_layer3_ebgp_candidate_router(add_link) }

        if region_as_params?
          make_layer3_topology_region_as(layer3_core_node)
        else
          make_layer3_topology_simple_as(layer3_core_node)
        end
      end

      # @param [Array<Hash>] flow_data Flow data
      # @return [Array<String>] items in specified column
      def column_items_from_flows(flow_data)
        column = @as_state[:type] == :source_as ? 'source' : 'dest'
        flow_data.map { |flow| flow[column] }.uniq
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
