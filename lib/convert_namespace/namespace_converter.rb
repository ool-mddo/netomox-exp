# frozen_string_literal: true

require 'forwardable'
require 'netomox'
require 'ipaddr'
require_relative 'namespace_converter_base'
require_relative 'namespace_convert_table/convert_table'

module NetomoxExp
  # rubocop:disable Metrics/ClassLength

  # namespace converter (original/emulated)
  class NamespaceConverter < NamespaceConverterBase
    extend Forwardable
    # @!method reload(table_data)
    #   @return [void]
    #   @see NamespaceConvertTable::ConvertTable#reload
    # @!method to_hash
    #   @return [Hash]
    #   @see NamespaceConvertTable::ConvertTable#to_hash
    # @!method node_name
    #   @return [NamespaceConvertTable::NodeNameTable]
    #   @see NamespaceConvertTable::ConvertTable#node_name_table
    # @!method tp_name
    #   @return [NamespaceConvertTable::TermPointTable]
    #   @see NamespaceConvertTable::ConvertTable#tp_name_table
    # @!method ospf_proc_id
    #   @return [NamespaceConvertTable::OspfProcIdTable]
    #   @see NamespaceConvertTable::ConvertTable#ospf_proc_id_table
    # @!method static_route_tp
    #   @return [NamespaceConvertTable::StaticRouteTpTable]
    #   @see NamespaceConvertTable::ConvertTable#static_route_tp_table
    delegate %i[reload to_hash node_name tp_name ospf_proc_id static_route_tp] => :@convert_table

    def initialize
      super

      @convert_table = NamespaceConvertTable::ConvertTable.new
    end

    # @param [Hash] topology_data Topology data (RFC8345 Hash)
    # @return [void]
    # @raise [StandardError] if @src_nws is not initialized
    def load_origin_topology(topology_data)
      super(topology_data)

      @convert_table.load_from_topology(topology_data)
    end

    # @return [void]
    def dump
      @dst_nws.dump
    end

    # Rewrite all networks using convert table
    # @return [Hash] Converted topology data
    def convert
      # destination: converted topology data (@src_nw -> @dst_nw)
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

    # @param [Netomox::Topology::Node] node
    def segment_node?(node)
      # segment node is only in L3 and OSPF_AREA network
      (layer3_node?(node) || ospf_node?(node)) && node.attribute.node_type == 'segment'
    end

    # @param [Netomox::Topology::TermPoint] src_tp Source term-point (L3+)
    # @return [Array<Array<String>>] Array of term-point supports
    def rewrite_tp_supports(src_tp)
      # ignore layer3 -> layer2 support info: these are not used in emulated env
      src_tp.supports
            .find_all { |tp_sup| target_network?(tp_sup.ref_network) }
            .map do |tp_sup|
        converted_node = node_name.convert(tp_sup.ref_node)['l3_model']
        converted_tp = tp_name.convert(tp_sup.ref_node, tp_sup.ref_tp)['l3_model']
        [tp_sup.ref_network, converted_node, converted_tp]
      end
    end

    # @param [Netomox::Topology::Node] src_node Source node (L3+)
    # @param [Netomox::Topology::TermPoint] src_tp Source term-point (L3+)
    # @return [Netomox::PseudoDSL::PTermPoint]
    def rewrite_term_point(src_node, src_tp)
      converted_node = tp_name.convert(src_node.name, src_tp.name)['l3_model']
      dst_tp = Netomox::PseudoDSL::PTermPoint.new(converted_node)
      dst_tp.attribute = convert_all_hash_keys(src_tp.attribute.to_data)
      dst_tp.supports = rewrite_tp_supports(src_tp)
      dst_tp
    end

    # @param [Netomox::Topology::Node] src_node Source node (L3+)
    # @return [Array<Array<String>>] Array of node supports
    def rewrite_node_support(src_node)
      # ignore layer3 -> layer2 support info: these are not used in emulated env
      src_node.supports
              .find_all { |node_sup| target_network?(node_sup.ref_network) }
              .map do |node_sup|
        converted_node = node_name.convert(node_sup.ref_node)['l3_model']
        [node_sup.ref_network, converted_node]
      end
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

    # @param [Netomox::Topology::Node] src_node Source node (L3+)
    # @param [Netomox::PseudoDSL::PNode] dst_node Destination node (L3+)
    # @return [void]
    # @raise [StandardError]
    def rewrite_layer3_node_attr(src_node, dst_node)
      return if dst_node.attribute[:static_routes].empty?

      # rewrite static route next-hop interface (if it is not 'dynamic')
      dst_node.attribute[:static_routes].each do |route|
        converted_tp = static_route_tp.convert(src_node.name, route[:prefix], route[:interface])
        route[:interface] = converted_tp
      end
    end

    # @param [Netomox::Topology::Node] src_node Source node (L3+)
    # @param [Netomox::PseudoDSL::PNode] dst_node Destination node (L3+)
    # @return [void]
    def rewrite_ospf_node_attr(src_node, dst_node)
      # rewrite ospf process-id in node-attribute of ospf-layer
      converted_proc_id = ospf_proc_id.convert(src_node.name, src_node.attribute.process_id.to_s)
      dst_node.attribute[:process_id] = converted_proc_id
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

    # rubocop:disable Metrics/AbcSize

    # @param [Netomox::Topology::Node] src_node Source node (L3+)
    # @return [Netomox::PseudoDSL::PNode]
    def rewrite_node(src_node)
      converted_node = node_name.convert(src_node.name)['l3_model']
      dst_node = Netomox::PseudoDSL::PNode.new(converted_node)
      dst_node.tps = src_node.termination_points.map { |src_tp| rewrite_term_point(src_node, src_tp) }
      dst_node.attribute = convert_all_hash_keys(src_node.attribute.to_data)
      dst_node.supports = rewrite_node_support(src_node)
      rewrite_node_attr(src_node, dst_node)
      dst_node
    end
    # rubocop:enable Metrics/AbcSize

    # @param [Netomox::Topology::TpRef] orig_edge Original link edge
    # @return [Netomox::PseudoDSL::PLinkEdge]
    def rewrite_link_edge(orig_edge)
      converted_node = node_name.convert(orig_edge.node_ref)['l3_model']
      converted_tp = tp_name.convert(orig_edge.node_ref, orig_edge.tp_ref)['l3_model']
      Netomox::PseudoDSL::PLinkEdge.new(converted_node, converted_tp)
    end

    # @param [Netomox::Topology::Link] src_link Source link (L3+)
    # @return [Netomox::PseudoDSL::PLink]
    def rewrite_link(src_link)
      dst_link_dst = rewrite_link_edge(src_link.source)
      dst_link_src = rewrite_link_edge(src_link.destination)
      Netomox::PseudoDSL::PLink.new(dst_link_dst, dst_link_src)
    end

    # rubocop:disable Metrics/AbcSize

    # @param [Netomox::PseudoDSL::Network] target_nw Destination network (L3)
    # @return [void]
    def update_tp_description(target_nw)
      target_nw.links.each do |link|
        target_node = target_nw.node(link.src.node)

        # Update target is source edge, Note: link is bidirectional
        target_node_dic = node_name.find_l1_alias(link.dst.node)
        target_tp = target_node.term_point(link.src.tp)
        target_tp_dic = tp_name.find_l1_alias(link.dst.node, link.dst.tp)
        target_tp.attribute[:description] = ['to', target_node_dic['l1_agent'], target_tp_dic['l1_agent']].join('_')
      end
    end
    # rubocop:enable Metrics/AbcSize

    # rubocop:disable Metrics/AbcSize

    # @param [Netomox::Topology::Network] src_nw Source network (L3+)
    # @return [Netomox::PseudoDSL::PNetwork]
    def rewrite_network(src_nw)
      dst_nw = Netomox::PseudoDSL::PNetwork.new(src_nw.name)
      # NOTE: network type is iterable hash
      dst_nw.type = src_nw.primary_network_type
      dst_nw.attribute = convert_all_hash_keys(src_nw.attribute.to_data) if src_nw.attribute
      dst_nw.supports = src_nw.supports.map(&:ref_network) if src_nw.supports
      dst_nw.nodes = src_nw.nodes.map { |src_node| rewrite_node(src_node) }
      dst_nw.links = src_nw.links.map { |src_link| rewrite_link(src_link) }
      # The interface description describes the information on the peer interface,
      # assuming the converted layer3 topology to be layer1.
      # Therefore, it must be updated when the conversion has been completed up to the link.
      update_tp_description(dst_nw) if dst_nw.name == 'layer3'
      dst_nw
    end
    # rubocop:enable Metrics/AbcSize
  end
  # rubocop:enable Metrics/ClassLength
end
