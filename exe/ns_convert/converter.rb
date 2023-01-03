# frozen_string_literal: true

require_relative 'convert_table'
require_relative 'util'
require_relative '../../model_defs/topology_builder/pseudo_dsl/pseudo_model'

module TopologyOperator
  # namespace converter
  class NamespaceConverter < NamespaceConvertTable
    # @param [String] file Topology file path
    def initialize(file)
      super(file)
      rewrite_networks
    end

    # @return [Hash]
    def to_data
      @dst_nws.interpret.topo_data
    end

    # @return [void]
    def dump
      @dst_nws.dump
    end

    private

    # @param [String] ref_network Support network (network name)
    # @param [String] ref_node Support node (node name)
    # @return [String] node name to support
    def support_node_name(ref_network, ref_node)
      # in layer2 node: "bridge(node)_interface" format
      return ref_node.split('_')[0] if ref_network == 'layer2'

      ref_node
    end

    # @param [Netomox::Topology::Node] src_node Source node (L3+)
    # @param [Netomox::Topology::TermPoint] src_tp Source term-point (L3+)
    # @return [TopologyBuilder::PseudoDSL::PTermPoint]
    def rewrite_term_point(src_node, src_tp)
      dst_tp = TopologyBuilder::PseudoDSL::PTermPoint.new(convert_tp_name(src_node.name, src_tp.name))
      dst_tp.attribute = convert_all_hash_keys(src_tp.attribute.to_data)
      dst_tp.supports = src_tp.supports.map do |tp_sup|
        ref_node = support_node_name(tp_sup.ref_network, tp_sup.ref_node)
        [tp_sup.ref_network, convert_node_name(ref_node), convert_tp_name(ref_node, tp_sup.ref_tp)]
      end
      dst_tp
    end

    # @param [Netomox::Topology::Node] src_node Source node (L3+)
    # @return [TopologyBuilder::PseudoDSL::PNode]
    def rewrite_node(src_node)
      src_node.termination_points.each do |src_tp|
        rewrite_term_point(src_node, src_tp)
      end

      dst_node = TopologyBuilder::PseudoDSL::PNode.new(convert_node_name(src_node.name))
      dst_node.attribute = convert_all_hash_keys(src_node.attribute.to_data)
      dst_node.supports = src_node.supports.map do |node_sup|
        ref_node = support_node_name(node_sup.ref_network, node_sup.ref_node)
        [node_sup.ref_network, convert_node_name(ref_node)]
      end
      dst_node
    end

    # @param [Netomox::Topology::Link] src_link Source link (L3+)
    # @return [TopologyBuilder::PseudoDSL::PLink]
    def rewrite_link(src_link)
      dst_link_dst = TopologyBuilder::PseudoDSL::PLinkEdge.new(
        convert_node_name(src_link.source.node_ref),
        convert_tp_name(src_link.source.node_ref, src_link.source.tp_ref)
      )
      dst_link_src = TopologyBuilder::PseudoDSL::PLinkEdge.new(
        convert_node_name(src_link.destination.node_ref),
        convert_tp_name(src_link.destination.node_ref, src_link.destination.tp_ref)
      )
      TopologyBuilder::PseudoDSL::PLink.new(dst_link_dst, dst_link_src)
    end

    # @param [Netomox::Topology::Network] src_nw Source network (L3+)
    # @return [TopologyBuilder::PseudoDSL::PNetwork]
    def rewrite_network(src_nw)
      dst_nw = TopologyBuilder::PseudoDSL::PNetwork.new(src_nw.name)
      # NOTE: network type is iterable hash
      dst_nw.type = src_nw.network_types.keys[0]
      dst_nw.attribute = convert_all_hash_keys(src_nw.attribute.to_data) unless src_nw.attribute
      dst_nw.supports = src_nw.supports.map { |nw_sup| [nw_sup.ref_network] } unless src_nw.supports
      dst_nw.nodes = src_nw.nodes.map { |src_node| rewrite_node(src_node) }
      dst_nw.links = src_nw.links.map { |src_link| rewrite_link(src_link) }
      dst_nw
    end

    # @return [void]
    def rewrite_networks
      target_nw_names = %w[ospf_area0 layer3]
      @dst_nws = TopologyBuilder::PseudoDSL::PNetworks.new
      @dst_nws.networks = @src_nws.networks
                                  .filter { |nw| target_nw_names.include?(nw.name) }
                                  .map { |src_nw| rewrite_network(src_nw) }
    end
  end
end