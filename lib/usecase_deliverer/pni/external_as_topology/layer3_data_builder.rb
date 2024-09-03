# frozen_string_literal: true

require 'ipaddr'
require 'netomox'

require_relative 'int_as_data_builder'
require_relative 'tiny_ipam'
require_relative 'layer3_data_builder_routers'
require_relative 'layer3_data_builder_ibgp_links'
require_relative 'layer3_data_builder_endpoint'

# Layer3 network data builder
class Layer3DataBuilder < IntASDataBuilder
  # @param [Symbol] as_type (enum: [source_as, :dest_as])
  # @param [Hash] usecase_params Params data
  # @param [Array<Hash>] usecase_flows Flow data
  # @param [Netomox::Topology::Networks] int_as_topology Internal AS topology (original_asis)
  def initialize(as_type, usecase_params, usecase_flows, int_as_topology)
    super(as_type, usecase_params, int_as_topology)

    @flow_prefixes = column_items_from_flows(usecase_flows)

    ipam = TinyIPAM.instance # singleton
    ipam.assign_base_prefix(@params['subnet'])

    # target external-AS topology (empty)
    @ext_as_topology = Netomox::PseudoDSL::PNetworks.new

    # layer3 network
    @layer3_nw = @ext_as_topology.network('layer3')
    @layer3_nw.type = Netomox::NWTYPE_MDDO_L3
    @layer3_nw.attribute = { name: 'mddo-layer3-network' }

    make_layer3_topology!
  end

  private

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
              .concat(find_all_layer3_ebgp_candidate_routers.map { |node| { node_name: node.name, node: node } })
              .combination(2)
              .to_a
  end

  # @return [void]
  def make_layer3_topology!
    # add core (aggregation) router
    layer3_core_node = add_layer3_core_router
    # add edge-router (ebgp speaker and inter-AS links)
    @peer_list.each_with_index { |peer_item, peer_index| add_layer3_edge_router(peer_item, peer_index) }
    # add edge-candidate-router (NOT ebgp yet, but will be ebgp)
    @params['add_links']&.each { |add_link| add_layer3_ebgp_candidate_router(add_link) }

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

  # @param [Array<Hash>] flow_data Flow data
  # @return [Array<String>] items in specified column
  def column_items_from_flows(flow_data)
    column = @as_state[:type] == :source_as ? 'source' : 'dest'
    flow_data.map { |flow| flow[column] }.uniq
  end
end
