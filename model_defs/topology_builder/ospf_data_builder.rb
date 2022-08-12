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

    # @param [PNode] l3node Layer3 node
    # @return [Hash] attribute
    def ospf_node_attr(l3node)
      l3node_is_seg_node = l3node.attribute[:node_type] == 'segment'
      ospf_proc_conf_rec = @ospf_proc_conf.find_record_by_node(l3node.name)
      return { node_type: 'segment' } if l3node_is_seg_node

      # TODO: ospf proc conf doesn't contains redistribute connected info?
      redistribute_attrs = [{ protocol: 'connected' }]
      redistribute_attrs.push({ protocol: 'static' }) if ospf_proc_conf_rec&.export_policy?('ospf-default')
      {
        node_type: l3node_is_seg_node ? 'segment' : 'ospf_proc',
        router_id: ospf_proc_conf_rec&.router_id || '',
        redistribute: redistribute_attrs
        # NOTE: log-adjacency-changes : No information in ospf-proc conf table
      }
    end

    # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength

    # @param l3node [PNode] l3node Layer3 node
    # @param l3tp [PTermPoint] l3tp Layer3 term-point
    # @return [Hash] attribute
    def ospf_tp_attr(l3node, l3tp)
      ospf_intf_conf_rec = @ospf_intf_conf.find_record_by_name(l3node.name, l3tp.name)
      l3node_is_seg_node = l3node.attribute[:node_type] == 'segment'
      return {} if l3node_is_seg_node

      {
        network_type: ospf_intf_conf_rec&.ospf_network_type || '',
        metric: ospf_intf_conf_rec&.ospf_cost || 10,
        passive: ospf_intf_conf_rec&.ospf_passive? || false,
        timer: {
          hello_interval: ospf_intf_conf_rec&.ospf_hello_interval || 10,
          dead_interval: ospf_intf_conf_rec&.ospf_dead_interval || 40
        }
      }
    end
    # rubocop:enable Metrics/CyclomaticComplexity, Metrics/MethodLength

    # rubocop:disable Metrics/AbcSize

    # @param [PLinkEdge] l3edge A edge of L3 link
    # @return [Array<PNode, PTermPoint>] A pair of added ospf node and term-point
    def add_ospf_node_tp(l3edge)
      l3node, l3tp = @layer3.find_node_tp_by_edge(l3edge)
      throw StandardError "Node #{l3edge.node} not found in #{@layer3.name}" if l3node.nil?

      ospf_node = @network.node(l3node.name)
      ospf_node.supports.push([@layer3.name, l3node.name])
      ospf_node.attribute = ospf_node_attr(l3node)

      ospf_tp = ospf_node.term_point(l3tp.name)
      ospf_tp.supports.push([@layer3.name, l3node.name, l3tp.name])
      ospf_tp.attribute = ospf_tp_attr(l3node, l3tp)

      [ospf_node, ospf_tp]
    end
    # rubocop:enable Metrics/AbcSize

    # @param [PNode] node1 Source ospf node
    # @param [PTermPoint] tp1 Source ospf term-point
    # @param [PNode] node2 Source ospf node
    # @param [PTermPoint] tp2 Source ospf term-point
    # @return [void]
    def add_ospf_link(node1, tp1, node2, tp2)
      @network.link(node1, tp1, node2, tp2)
      @network.link(node2, tp2, node1, tp1) # bidirectional
    end

    # rubocop:disable Metrics/AbcSize

    # @param [Array<PLink>] l3links Layer3 links sourced a segment-node
    def add_ospf_node_tp_link(l3links)
      l3links.each do |l3link|
        dst_intf_conf = @ospf_intf_conf.find_record_by_name(l3link.dst.node, l3link.dst.tp)
        next if dst_intf_conf.nil? || !dst_intf_conf.ospf_enabled?

        n1, tp1 = add_ospf_node_tp(l3link.src) # segment node
        n2, tp2 = add_ospf_node_tp(l3link.dst)
        add_ospf_link(n1.name, tp1.name, n2.name, tp2.name)
      end
    end
    # rubocop:enable Metrics/AbcSize

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
