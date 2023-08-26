# frozen_string_literal: true

require 'netomox'
require_relative 'namespace_converter_base'

module NetomoxExp
  # filter L3+ (upper layer3...layer3 + OSPF-areaN + BGP-proc/as)
  # NOTE: it requires inherit NamespaceConverter to use convert_all_hash_keys
  class UpperLayer3Filter < NamespaceConverterBase
    # @param [Hash] topology_data Topology data
    def initialize(topology_data)
      super()
      load_origin_topology(topology_data)
    end

    # @return [Hash]
    def filter
      @dst_nws = Netomox::PseudoDSL::PNetworks.new
      @dst_nws.networks = @src_nws.networks.filter { |nw| target_network?(nw.name) }
                                  .map { |src_nw| filter_network(src_nw) }
      @dst_nws.interpret.topo_data
    end

    private

    # @param [Netomox::Topology::TermPoint] src_tp Source term-point (L3+)
    # @return [Array<Array<String>>] Array of term-point supports
    def filter_tp_support(src_tp)
      src_tp.supports
            .find_all { |tp_sup| target_network?(tp_sup.ref_network) }
            .map { |tp_sup| [tp_sup.ref_network, tp_sup.ref_node, tp_sup.ref_tp] }
    end

    # @param [Netomox::Topology::TermPoint] src_tp Source term-point (L3+)
    # @return [Netomox::PseudoDSL::PTermPoint]
    def filter_term_point(src_tp)
      dst_tp = Netomox::PseudoDSL::PTermPoint.new(src_tp.name)
      dst_tp.attribute = convert_all_hash_keys(src_tp.attribute.to_data)
      dst_tp.supports = filter_tp_support(src_tp)
      dst_tp
    end

    # @param [Netomox::Topology::Node] src_node Source node (L3+)
    # @return [Array<Array<String>>] Array of node supports
    def filter_node_support(src_node)
      src_node.supports
              .find_all { |node_sup| target_network?(node_sup.ref_network) }
              .map { |node_sup| [node_sup.ref_network, node_sup.ref_node] }
    end

    # @param [Netomox::Topology::Node] src_node Source node (L3+)
    # @return [Netomox::PseudoDSL::PNode]
    def filter_node(src_node)
      dst_node = Netomox::PseudoDSL::PNode.new(src_node.name)
      dst_node.tps = src_node.termination_points.map { |src_tp| filter_term_point(src_tp) }
      dst_node.attribute = convert_all_hash_keys(src_node.attribute.to_data)
      dst_node.supports = filter_node_support(src_node)
      dst_node
    end

    # @param [Netomox::Topology::TpRef] orig_edge Original link edge
    # @return [Netomox::PseudoDSL::PLinkEdge]
    def link_edge(orig_edge)
      Netomox::PseudoDSL::PLinkEdge.new(orig_edge.node_ref, orig_edge.tp_ref)
    end

    # @param [Netomox::Topology::Link] src_link Source link (L3+)
    # @return [Netomox::PseudoDSL::PLink]
    def filter_link(src_link)
      # NOTE: Currently, Link support/attribute are not used (empty)
      Netomox::PseudoDSL::PLink.new(link_edge(src_link.source), link_edge(src_link.destination))
    end

    # rubocop:disable Metrics/AbcSize

    # @param [Netomox::Topology::Network] src_nw Source network (L3+)
    # @return [Netomox::PseudoDSL::PNetwork]
    def filter_network(src_nw)
      dst_nw = Netomox::PseudoDSL::PNetwork.new(src_nw.name)
      # NOTE: network type is iterable hash
      dst_nw.type = src_nw.primary_network_type
      dst_nw.attribute = convert_all_hash_keys(src_nw.attribute.to_data) if src_nw.attribute
      dst_nw.supports = src_nw.supports.map(&:ref_network) if src_nw.supports
      dst_nw.nodes = src_nw.nodes.map { |src_node| filter_node(src_node) }
      dst_nw.links = src_nw.links.map { |src_link| filter_link(src_link) }
      dst_nw
    end
    # rubocop:enable Metrics/AbcSize
  end
end
