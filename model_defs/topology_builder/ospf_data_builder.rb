# frozen_string_literal: true

require_relative 'pseudo_dsl/pseudo_model'
require_relative 'csv_mapper/ospf_area_conf_table'
require_relative 'csv_mapper/ospf_intf_conf_table'
require_relative 'csv_mapper/ospf_proc_conf_table'

module TopologyBuilder
  # rubocop:disable Metrics/ClassLength

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
        update_ospf_neighbor_attr
      end
      @networks
    end

    private

    # @return [Array<PNode>] Layer3 segment nodes
    def find_all_l3_segment_type_nodes
      @layer3.nodes.find_all { |node| node.attribute[:node_type] == 'segment' }
    end

    # @return [Array<PNode>] ospf-area segment node
    def find_all_ospf_segment_type_nodes
      @network.nodes.find_all { |node| node.attribute[:node_type] == 'segment' }
    end

    # @param [PNode] l3_node Layer3 node
    # @return [Hash] attribute
    def ospf_node_attr(l3_node)
      l3_node_is_seg_node = l3_node.attribute[:node_type] == 'segment'
      ospf_proc_conf_rec = @ospf_proc_conf.find_record_by_node(l3_node.name)
      return { node_type: 'segment' } if l3_node_is_seg_node

      # TODO: ospf proc conf doesn't contains redistribute connected info?
      redistribute_attrs = [{ protocol: 'connected' }]
      redistribute_attrs.push({ protocol: 'static' }) if ospf_proc_conf_rec&.export_policy?('ospf-default')
      {
        node_type: l3_node_is_seg_node ? 'segment' : 'ospf_proc',
        router_id: ospf_proc_conf_rec&.router_id || '',
        redistribute: redistribute_attrs
        # NOTE: log-adjacency-changes : No information in ospf-proc conf table
      }
    end

    # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength

    # @param l3_node [PNode] l3node Layer3 node
    # @param l3_tp [PTermPoint] l3tp Layer3 term-point
    # @return [Hash] attribute
    def ospf_tp_attr(l3_node, l3_tp)
      ospf_intf_conf_rec = @ospf_intf_conf.find_record_by_node_intf(l3_node.name, l3_tp.name)
      l3_node_is_seg_node = l3_node.attribute[:node_type] == 'segment'
      return {} if l3_node_is_seg_node

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

    # @param [PLinkEdge] l3_edge A edge of L3 link
    # @return [Array<PNode, PTermPoint>] A pair of added ospf node and term-point
    def add_ospf_node_tp(l3_edge)
      l3_node, l3_tp = @layer3.find_node_tp_by_edge(l3_edge)
      throw StandardError "Node #{l3_edge.node} not found in #{@layer3.name}" if l3_node.nil?

      ospf_node = @network.node(l3_node.name)
      ospf_node.supports.push([@layer3.name, l3_node.name])
      ospf_node.attribute = ospf_node_attr(l3_node)

      ospf_tp = ospf_node.term_point(l3_tp.name)
      ospf_tp.supports.push([@layer3.name, l3_node.name, l3_tp.name])
      ospf_tp.attribute = ospf_tp_attr(l3_node, l3_tp)

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

    # @param [Array<PLink>] l3_links Layer3 links sourced a segment-node
    def add_ospf_node_tp_link(l3_links)
      l3_links.each do |l3_link|
        dst_intf_conf = @ospf_intf_conf.find_record_by_node_intf(l3_link.dst.node, l3_link.dst.tp)
        next if dst_intf_conf.nil? || !dst_intf_conf.ospf_enabled?

        n1, tp1 = add_ospf_node_tp(l3_link.src) # segment node
        n2, tp2 = add_ospf_node_tp(l3_link.dst)
        add_ospf_link(n1.name, tp1.name, n2.name, tp2.name)
      end
    end
    # rubocop:enable Metrics/AbcSize

    # @return [void]
    def setup_ospf_topology
      segment_nodes = find_all_l3_segment_type_nodes
      segment_nodes.each do |seg_node|
        links = @layer3.find_all_links_by_src_name(seg_node.name)
        add_ospf_node_tp_link(links)
      end
    end

    # @param [PNodeEdge] edge Link edge
    # @return [Array<PNode, PTermPoint, OspfProcessConfigurationTableRecord>]
    def find_ospf_node_tp_conf(edge)
      node, tp = @network.find_node_tp_by_edge(edge)
      return [nil, nil, nil] if node.nil? || tp.nil?

      conf = @ospf_intf_conf.find_record_by_node_intf(node.name, tp.name)
      [node, tp, conf]
    end

    # rubocop:disable Metrics/AbcSize

    # @param [PTermPoint] target_tp Update target term-point
    # @param [PNode] other_node Neighbor node of target
    # @param [PTermPoint] other_tp Neighbor term-point of target
    # @return [void]
    def update_tp_neighbor_attr(target_tp, other_node, other_tp)
      stp = other_tp.supports.find { |s| s[0] == @layer3.name } # support-tp element is [nw, node, tp] array
      _, other_stp = @layer3.find_node_tp_by_name(stp[1], stp[2])
      neighbor = {
        router_id: other_node.attribute[:router_id],
        ip_addr: other_stp.attribute[:ip_addrs][0]
      }
      if !target_tp.attribute.key?(:neighbors) || target_tp.attribute[:neighbors].nil?
        target_tp.attribute[:neighbors] = []
      end
      target_tp.attribute[:neighbors].push(neighbor)
    end
    # rubocop:enable Metrics/AbcSize

    # @param [PTermPoint] target_tp Update target term-point
    # @param [Array<PLinkEdge>] other_edges neighbor candidate term-points (edges)
    # @return [void]
    def listing_neighbors_and_update(target_tp, other_edges)
      other_edges.each do |other_edge|
        other_node, other_tp, other_conf = find_ospf_node_tp_conf(other_edge)
        next if other_conf.nil? || !other_conf.ospf_active?

        update_tp_neighbor_attr(target_tp, other_node, other_tp)
      end
    end

    # @return [void]
    def update_ospf_neighbor_attr
      segment_nodes = find_all_ospf_segment_type_nodes
      segment_nodes.each do |seg_node|
        edges = @network.find_all_edges_by_src_name(seg_node.name)
        edges.each do |target_edge|
          _, target_tp, target_conf = find_ospf_node_tp_conf(target_edge)
          next if target_conf.nil? || !target_conf.ospf_active?

          listing_neighbors_and_update(target_tp, edges - [target_edge])
        end
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end
