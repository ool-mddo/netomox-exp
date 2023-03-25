# frozen_string_literal: true

require 'netomox'
require 'ipaddr'
require_relative 'namespace_convert_table'

# rubocop:disable Metrics/ClassLength

# namespace converter (original/emulated)
class NamespaceConverter < NamespaceConvertTable
  # @return [void]
  def dump
    @dst_nws.dump
  end

  # Rewrite all networks using convert table
  # @return [Hash] Converted topology data
  def convert
    @dst_nws = Netomox::PseudoDSL::PNetworks.new
    @dst_nws.networks = @src_nws.networks
                                .filter { |nw| target_network?(nw.name) }
                                .map { |src_nw| rewrite_network(src_nw) }
    @dst_nws.interpret.topo_data
  end

  protected

  # @param [Netomox::Topology::Node] node Node
  # @return [Boolean] True if the node is in ospf-layer
  def ospf_node?(node)
    node.attribute.is_a?(Netomox::Topology::MddoOspfAreaNodeAttribute)
  end

  # @param [Netomox::Topology::Node] node Node
  # @return [Boolean] True if the node is in layer3
  def layer3_node?(node)
    node.attribute.is_a?(Netomox::Topology::MddoL3NodeAttribute)
  end

  private

  # @param [Netomox::Topology::TermPoint] src_tp Source term-point (L3+)
  # @param [Netomox::PseudoDSL::PTermPoint] dst_tp Destination term-point (L3+)
  # return [void]
  def rewrite_layer3_tp_attr(src_tp, dst_tp)
    return if src_tp.attribute.description.empty?

    # rewrite interface description
    _, src_host_name, src_tp_name = src_tp.attribute.description.split('_') # "[to, <host>, <tp>]"
    # NOTICE: host and interface(term-point) name in description is not normalized
    dst_host_name = convert_node_name(src_host_name.downcase)
    dst_tp_name = convert_tp_name_match(src_host_name.downcase, Regexp.new("#{src_tp_name}.*$")) # ignore unit number
    dst_tp.attribute[:description] = ['to', dst_host_name, dst_tp_name].join('_')
  end

  # @param [Netomox::Topology::TermPoint] src_tp Source term-point (L3+)
  # @return [Array<Array<String>>] Array of term-point supports
  def rewrite_tp_supports(src_tp)
    # ignore layer3 -> layer2 support info: these are not used in emulated env
    src_tp.supports
          .find_all { |tp_sup| target_network?(tp_sup.ref_network) }
          .map do |tp_sup|
      converted_tp = convert_tp_name(tp_sup.ref_node, tp_sup.ref_tp)
      [tp_sup.ref_network, convert_node_name(tp_sup.ref_node), converted_tp]
    end
  end

  # @param [Netomox::Topology::Node] src_node Source node (L3+)
  # @param [Netomox::Topology::TermPoint] src_tp Source term-point (L3+)
  # @return [Netomox::PseudoDSL::PTermPoint]
  def rewrite_term_point(src_node, src_tp)
    dst_tp = Netomox::PseudoDSL::PTermPoint.new(convert_tp_name(src_node.name, src_tp.name))
    dst_tp.attribute = convert_all_hash_keys(src_tp.attribute.to_data)
    dst_tp.supports = rewrite_tp_supports(src_tp)
    rewrite_layer3_tp_attr(src_tp, dst_tp) if layer3_node?(src_node) && !segment_node?(src_node)
    dst_tp
  end

  # @param [Netomox::Topology::Node] src_node Source node (L3+)
  # @return [Array<Array<String>>] Array of node supports
  def rewrite_node_support(src_node)
    # ignore layer3 -> layer2 support info: these are not used in emulated env
    src_node.supports
            .find_all { |node_sup| target_network?(node_sup.ref_network) }
            .map { |node_sup| [node_sup.ref_network, convert_node_name(node_sup.ref_node)] }
  end

  # @param [Netomox::PseudoDSL::PNode] node Node (destination)
  # @param [String] next_hop Next-hop IP address of a static-route
  # @return [nil, Netomox::PseudoDSL::PTermPoint] Term-point that is connected with next-hop segment
  def find_next_hop_interface(node, next_hop)
    node.tps.find do |tp|
      tp.attribute[:ip_addrs]
        .map { |ip_addr| IPAddr.new(ip_addr) }
        .any? { |ip_addr| ip_addr.include?(next_hop) }
    end
  end

  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize

  # @param [Netomox::Topology::Node] src_node Source node (L3+)
  # @param [Netomox::PseudoDSL::PNode] dst_node Destination node (L3+)
  # @return [void]
  # @raise [StandardError]
  def rewrite_layer3_node_attr(src_node, dst_node)
    return if dst_node.attribute[:static_routes].empty?

    # rewrite static route next-hop
    dst_node.attribute[:static_routes].reject { |r| r[:interface] == 'dynamic' }.each do |route|
      route[:interface] = convert_tp_name(src_node.name, route[:interface])
    end
    dst_node.attribute[:static_routes].select { |r| r[:interface] == 'dynamic' }.each do |route|
      tp = find_next_hop_interface(dst_node, route[:next_hop])
      if tp.nil?
        raise StandardError,
              "Static route: prefix=#{route[:prefix]}, next-hop=#{route[:next_hop]}: next hop is not local address"
      end
      route[:interface] = tp.name
    end
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

  # @param [Netomox::Topology::Node] src_node Source node (L3+)
  # @param [Netomox::PseudoDSL::PNode] dst_node Destination node (L3+)
  # @return [void]
  def rewrite_ospf_node_attr(src_node, dst_node)
    # rewrite ospf process-id in node-attribute of ospf-layer
    dst_node.attribute[:process_id] = convert_ospf_proc_id(src_node.name, src_node.attribute.process_id)
  end

  # @param [Netomox::Topology::Node] src_node Source node (L3+)
  # @param [Netomox::PseudoDSL::PNode] dst_node Destination node (L3+)
  # @return [void]
  def rewrite_node_attr(src_node, dst_node)
    # ignore segment node in layer3/ospf layer
    return if segment_node?(src_node)

    rewrite_layer3_node_attr(src_node, dst_node) if layer3_node?(src_node)
    rewrite_ospf_node_attr(src_node, dst_node) if ospf_node?(src_node)
  end

  # @param [Netomox::Topology::Node] src_node Source node (L3+)
  # @return [Netomox::PseudoDSL::PNode]
  def rewrite_node(src_node)
    dst_node = Netomox::PseudoDSL::PNode.new(convert_node_name(src_node.name))
    dst_node.tps = src_node.termination_points.map { |src_tp| rewrite_term_point(src_node, src_tp) }
    dst_node.attribute = convert_all_hash_keys(src_node.attribute.to_data)
    dst_node.supports = rewrite_node_support(src_node)
    rewrite_node_attr(src_node, dst_node)
    dst_node
  end

  # @param [Netomox::Topology::TpRef] orig_edge Original link edge
  # @return [Netomox::PseudoDSL::PLinkEdge]
  def rewrite_link_edge(orig_edge)
    node = convert_node_name(orig_edge.node_ref)
    tp = convert_tp_name(orig_edge.node_ref, orig_edge.tp_ref)
    Netomox::PseudoDSL::PLinkEdge.new(node, tp)
  end

  # @param [Netomox::Topology::Link] src_link Source link (L3+)
  # @return [Netomox::PseudoDSL::PLink]
  def rewrite_link(src_link)
    dst_link_dst = rewrite_link_edge(src_link.source)
    dst_link_src = rewrite_link_edge(src_link.destination)
    Netomox::PseudoDSL::PLink.new(dst_link_dst, dst_link_src)
  end

  # rubocop:disable Metrics/AbcSize

  # @param [Netomox::Topology::Network] src_nw Source network (L3+)
  # @return [Netomox::PseudoDSL::PNetwork]
  def rewrite_network(src_nw)
    dst_nw = Netomox::PseudoDSL::PNetwork.new(src_nw.name)
    # NOTE: network type is iterable hash
    dst_nw.type = src_nw.network_types.keys[0]
    dst_nw.attribute = convert_all_hash_keys(src_nw.attribute.to_data) if src_nw.attribute
    dst_nw.supports = src_nw.supports.map(&:ref_network) if src_nw.supports
    dst_nw.nodes = src_nw.nodes.map { |src_node| rewrite_node(src_node) }
    dst_nw.links = src_nw.links.map { |src_link| rewrite_link(src_link) }
    dst_nw
  end
  # rubocop:enable Metrics/AbcSize
end
# rubocop:enable Metrics/ClassLength
