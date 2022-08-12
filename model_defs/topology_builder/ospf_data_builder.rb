# frozen_string_literal: true

require_relative 'pseudo_dsl/pseudo_model'
require_relative 'csv_mapper/ospf_area_conf_table'
require_relative 'csv_mapper/ospf_intf_conf_table'
require_relative 'csv_mapper/ospf_proc_conf_table'

module TopologyBuilder
  # OSPF data builder
  class OspfDataBuilder < PseudoDSL::DataBuilderBase
    # @param [String] target Target network (config) data name
    # @param [PNetwork] layer3 Layer3 network topology
    def initialize(target:, layer3:, debug: false)
      super(debug: debug)
      @layer3 = layer3
      @ospf_area_conf = CSVMapper::OspfAreaConfigurationTable.new(target)
      @ospf_intf_conf = CSVMapper::OspfInterfaceConfigurationTable.new(target)
      @ospf_proc_conf = CSVMapper::OspfProcessConfigurationTable.new(target)
    end

    # @return [PNetworks] Networks contains ospf area topology
    def make_networks
      @ospf_area_conf.all_areas.each do |area_id|
        @area_id = area_id
        @network = @networks.network("ospf_area#{@area_id}")
        @network.type = Netomox::NWTYPE_MDDO_OSPF_AREA
        setup_ospf_topology
      end
      @networks
    end

    private

    # @return [Array<PNode>] Layer3 segment nodes
    def find_all_segment_type_nodes
      @layer3.nodes.find_all { |node| node.attribute[:node_type] == 'segment' }
    end

    # @param [PLinkEdge] l3edge A edge of L3 link
    # @return [Array<PNode, PTermPoint>] A pair of added ospf node and term-point
    def add_ospf_node_tp(l3edge)
      ospf_node = @network.node(l3edge.node)
      ospf_tp = ospf_node.term_point(l3edge.tp)
      [ospf_node, ospf_tp]
    end

    # @param [PNode] node1 Source ospf node
    # @param [PTermPoint] tp1 Source ospf term-point
    # @param [PNode] node2 Source ospf node
    # @param [PTermPoint] tp2 Source ospf term-point
    # @return [void]
    def add_ospf_link(node1, tp1, node2, tp2)
      @network.link(node1, tp1, node2, tp2)
    end

    # @param [Array<PLink>] l3links Layer3 links sourced a segment-node
    def add_ospf_node_tp_link(l3links)
      l3links.each do |l3link|
        # puts "# L3link = #{l3link}"
        dst_intf_conf = @ospf_intf_conf.find_record_by_name(l3link.dst.node, l3link.dst.tp)
        # puts "# dst_intf = #{dst_intf_conf} = #{dst_intf_conf.nil?}"
        next if dst_intf_conf.nil? || !dst_intf_conf.ospf_enabled?

        n1, tp1 = add_ospf_node_tp(l3link.src) # segment node
        n2, tp2 = add_ospf_node_tp(l3link.dst)
        # puts "n1: #{n1}, tp1: #{tp1}, n2: #{n2}, tp2: #{tp2}"
        add_ospf_link(n1.name, tp1.name, n2.name, tp2.name)
      end
    end

    # @return [void]
    def setup_ospf_topology
      segment_nodes = find_all_segment_type_nodes
      segment_nodes.each do |seg_node|
        links = @layer3.find_all_links_by_src_name(seg_node.name)
        add_ospf_node_tp_link(links)
      end
    end
  end
end
