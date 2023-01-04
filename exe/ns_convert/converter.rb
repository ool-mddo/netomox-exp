# frozen_string_literal: true

require_relative 'convert_table'
require_relative 'util'
require_relative '../../model_defs/topology_builder/pseudo_dsl/pseudo_model'

module TopologyOperator
  # namespace converter
  class NamespaceConverter < NamespaceConvertTable
    TARGET_NW_REGEXP_LIST = [/ospf_area\d+/, /layer3/].freeze

    # @return [Hash]
    def topo_data
      @dst_nws.interpret.topo_data
    end

    # @return [void]
    def dump
      @dst_nws.dump
    end

    # @return [void]
    def rewrite_networks
      @dst_nws = TopologyBuilder::PseudoDSL::PNetworks.new
      @dst_nws.networks = @src_nws.networks
                                  .filter { |nw| target_network?(nw.name) }
                                  .map { |src_nw| rewrite_network(src_nw) }
    end

    private

    # @return [Boolean] True if the network_name matches one of TARGET_NW_REGEXP_LIST
    def target_network?(network_name)
      TARGET_NW_REGEXP_LIST.any? { |nw_re| network_name =~ nw_re }
    end

    # @param [String] ref_network Support network (network name)
    # @param [String] ref_node Support node (node name)
    # @return [Array<String>] node name to support
    def support_node_name(ref_network, ref_node)
      return [ref_node] if ref_network != 'layer2'

      # in layer2 node: "bridge(node)_interface" format
      ref_node.split('_')
    end

    # @param [Netomox::Topology::TermPoint] src_tp Source term-point (L3+)
    # @return [Array<Array<String>>] Array of term-point supports
    def rewrite_tp_supports(src_tp)
      src_tp.supports
            .map do |tp_sup|
        n_node, n_tp = support_node_name(tp_sup.ref_network, tp_sup.ref_node)

        converted_tp = convert_tp_name(n_node, tp_sup.ref_tp)
        if n_tp.nil?
          [tp_sup.ref_network, convert_node_name(n_node), converted_tp]
        else
          [tp_sup.ref_network, [convert_node_name(n_node), convert_tp_name(n_node, n_tp)].join('_'), converted_tp]
        end
      end
    end

    # @param [Netomox::Topology::Node] src_node Source node (L3+)
    # @param [Netomox::Topology::TermPoint] src_tp Source term-point (L3+)
    # @return [TopologyBuilder::PseudoDSL::PTermPoint]
    def rewrite_term_point(src_node, src_tp)
      dst_tp = TopologyBuilder::PseudoDSL::PTermPoint.new(convert_tp_name(src_node.name, src_tp.name))
      dst_tp.attribute = convert_all_hash_keys(src_tp.attribute.to_data)
      dst_tp.supports = rewrite_tp_supports(src_tp)
      dst_tp
    end

    # @param [Netomox::Topology::Node] src_node Source node (L3+)
    # @return [Array<Array<String>>] Array of node supports
    def rewrite_node_support(src_node)
      src_node.supports
              .map do |node_sup|
        n_node, n_tp = support_node_name(node_sup.ref_network, node_sup.ref_node)
        if n_tp.nil?
          [node_sup.ref_network, convert_node_name(n_node)]
        else
          [node_sup.ref_network, [convert_node_name(n_node), convert_tp_name(n_node, n_tp)].join('_')]
        end
      end
    end

    # @param [Netomox::Topology::Node] src_node Source node (L3+)
    # @return [TopologyBuilder::PseudoDSL::PNode]
    def rewrite_node(src_node)
      dst_node = TopologyBuilder::PseudoDSL::PNode.new(convert_node_name(src_node.name))
      dst_node.tps = src_node.termination_points.map { |src_tp| rewrite_term_point(src_node, src_tp) }
      dst_node.attribute = convert_all_hash_keys(src_node.attribute.to_data)
      dst_node.supports = rewrite_node_support(src_node)
      dst_node
    end

    # rubocop:disable Metrics/AbcSize

    # @param [Netomox::Topology::Link] src_link Source link (L3+)
    # @return [TopologyBuilder::PseudoDSL::PLink]
    def rewrite_link(src_link)
      ss_node = convert_node_name(src_link.source.node_ref)
      ss_tp = convert_tp_name(src_link.source.node_ref, src_link.source.tp_ref)
      dst_link_dst = TopologyBuilder::PseudoDSL::PLinkEdge.new(ss_node, ss_tp)

      sd_node = convert_node_name(src_link.destination.node_ref)
      sd_tp = convert_tp_name(src_link.destination.node_ref, src_link.destination.tp_ref)
      dst_link_src = TopologyBuilder::PseudoDSL::PLinkEdge.new(sd_node, sd_tp)

      TopologyBuilder::PseudoDSL::PLink.new(dst_link_dst, dst_link_src)
    end
    # rubocop:enable Metrics/AbcSize

    # rubocop:disable Metrics/AbcSize

    # @param [Netomox::Topology::Network] src_nw Source network (L3+)
    # @return [TopologyBuilder::PseudoDSL::PNetwork]
    def rewrite_network(src_nw)
      dst_nw = TopologyBuilder::PseudoDSL::PNetwork.new(src_nw.name)
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
end
