# frozen_string_literal: true

require_relative 'pseudo_model'
require_relative 'csv_mapper/ospf_area_conf_table'
require_relative 'csv_mapper/ospf_intf_conf_table'
require_relative 'csv_mapper/ospf_proc_conf_table'
require_relative 'csv_mapper/named_structures_table'
require 'ipaddress'

module TopologyBuilder
  # rubocop:disable Metrics/ClassLength

  # OSPF data builder
  class OspfDataBuilder < DataBuilderBase
    # @param [String] target Target network (config) data name
    # @param [Netomox::PseudoDSL::PNetwork] layer3p Layer3 network topology
    def initialize(target:, layer3p:, debug: false)
      super(debug:)
      @layer3p = layer3p
      @ospf_area_conf = CSVMapper::OspfAreaConfigurationTable.new(target)
      @ospf_intf_conf = CSVMapper::OspfInterfaceConfigurationTable.new(target)
      @ospf_proc_conf = CSVMapper::OspfProcessConfigurationTable.new(target)
      @named_structures = CSVMapper::NamedStructuresTable.new(target)
    end

    # @return [Netomox::PseudoDSL::PNetworks] Networks contains ospf area topology
    def make_networks
      # NOTE: ospf layer is defined for each ospf-area
      @ospf_area_conf.all_areas.each do |area_id|
        # set context
        @area_id = area_id
        @network = @networks.network("ospf_area#{@area_id}")
        # setup network (per ospf-area) data
        setup_ospf_network_attr
        setup_ospf_topology
        update_ospf_neighbor_attr
      end
      # the `networks` contains multiple ospf-area network
      @networks
    end

    private

    # @return [void]
    def setup_ospf_network_attr
      @network.type = Netomox::NWTYPE_MDDO_OSPF_AREA
      @network.supports.push(@layer3p.name)
      @network.attribute = {
        name: 'mddo-ospf-area-network',
        identifier: dotted_quad_area_id
      }
    end

    # @return [String] Dotted-quad format area id
    def dotted_quad_area_id
      IPAddress::IPv4.parse_u32(@area_id).address
    end

    # @param [Netomox::PseudoDSL::PNetwork] target_network Network to search
    # @return [Array<Netomox::PseudoDSL::PNode>] Layer3 segment nodes
    def find_all_segment_type_nodes(target_network)
      target_network.nodes.find_all { |node| node.attribute[:node_type] == 'segment' }
    end

    # @return [Array<Netomox::PseudoDSL::PNode>] Layer3 segment nodes
    def find_all_l3_segment_type_nodes
      find_all_segment_type_nodes(@layer3p)
    end

    # @return [Array<Netomox::PseudoDSL::PNode>] ospf-area segment node
    def find_all_ospf_segment_type_nodes
      find_all_segment_type_nodes(@network)
    end

    # @param [Netomox::PseudoDSL::PNode] l3_node L3 node to check
    # @return [Boolean] true if the node type is segment
    def segment_type_l3_node?(l3_node)
      l3_node.attribute[:node_type] == 'segment'
    end

    # @param [OspfProcessConfigurationTableRecord] ospf_proc_conf_rec
    # @return [Array<Hash>] ospf redistribute attribute data
    def ospf_node_redistribute_attrs(ospf_proc_conf_rec)
      debug_print "  # ospf-export: #{ospf_proc_conf_rec.export_policy_sources}"
      redistribute_protocols = ospf_proc_conf_rec.export_policy_sources.map do |policy_source|
        rec = @named_structures.find_record_by_node_structure(ospf_proc_conf_rec.node, policy_source)
        rec ? rec.ospf_redistribute_protocols : []
      end
      debug_print "  # ospf-redistribute: #{redistribute_protocols.flatten}"
      redistribute_protocols.flatten.map { |proto| { protocol: proto } }
    end

    # @param [Netomox::PseudoDSL::PNode] l3_node Layer3 node
    # @return [Hash] attribute
    def ospf_node_attr(l3_node)
      ospf_proc_conf_rec = @ospf_proc_conf.find_record_by_node(l3_node.name)
      # default attribute for segment-type ospf-node
      return { node_type: 'segment' } if segment_type_l3_node?(l3_node)

      {
        node_type: 'ospf_proc',
        router_id: ospf_proc_conf_rec ? ospf_proc_conf_rec.router_id : '',
        process_id: ospf_proc_conf_rec ? ospf_proc_conf_rec.process_id : 'default',
        redistribute: ospf_proc_conf_rec ? ospf_node_redistribute_attrs(ospf_proc_conf_rec) : []
        # NOTE: log-adjacency-changes : No information in ospf-proc conf table
      }
    end

    # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength

    # @param l3_node [Netomox::PseudoDSL::PNode] l3node Layer3 node
    # @param l3_tp [Netomox::PseudoDSL::PTermPoint] l3tp Layer3 term-point
    # @return [Hash] attribute
    def ospf_tp_attr(l3_node, l3_tp)
      ospf_intf_conf = @ospf_intf_conf.find_record_by_node_intf(l3_node.name, l3_tp.name)
      # empty (default) term-point attribute for segment-type ospf-node
      return {} if segment_type_l3_node?(l3_node)

      # attribute for a term-point in ospf-proc type ospf-node
      {
        network_type: ospf_intf_conf&.ospf_network_type || '',
        metric: ospf_intf_conf&.ospf_cost || 10,
        passive: ospf_intf_conf&.ospf_passive? || false,
        timer: {
          hello_interval: ospf_intf_conf&.ospf_hello_interval || 10,
          dead_interval: ospf_intf_conf&.ospf_dead_interval || 40
        }
      }
    end
    # rubocop:enable Metrics/CyclomaticComplexity, Metrics/MethodLength

    # @param [Netomox::PseudoDSL::PLinkEdge] l3_edge A edge of L3 link
    # @return [Array(Netomox::PseudoDSL::PNode, Netomox::PseudoDSL::PTermPoint)] pair of node/tp
    def l3_edge_to_object(l3_edge)
      l3_node, l3_tp = @layer3p.find_node_tp_by_edge(l3_edge)
      raise StandardError "Node #{l3_edge.node} not found in #{@layer3p.name}" if l3_node.nil?

      [l3_node, l3_tp]
    end

    # @param [Netomox::PseudoDSL::PNode] l3_node Layer3 node
    # @param [String] flag A string in flags
    # @return [Array<Netomox::PseudoDSL::PTermPoint>]
    #   Term-points in l3_node that has flag in its attribute.flags
    def find_all_l3_tps_by_flags(l3_node, flag)
      l3_node.tps.find_all do |tp|
        tp.attribute&.key?(:flags) && tp.attribute[:flags].include?(flag)
      end
    end

    # add loopback term-point to ospf-are anode if origin (layer3) node has loopback
    # @param [Netomox::PseudoDSL::PLinkEdge] l3_edge A edge of L3 link
    # @return [void]
    def add_ospf_node_loopback_tp(l3_edge)
      l3_node, = l3_edge_to_object(l3_edge)
      ospf_node = @network.node(l3_node.name)
      debug_print "  # Add loopback interface to #{ospf_node.name} from #{l3_node.name}"

      find_all_l3_tps_by_flags(l3_node, 'loopback').each do |l3_tp_lo|
        debug_print "    - add: #{l3_tp_lo.name} to #{ospf_node.name}"
        add_tp_to_ospf_node(l3_node, l3_tp_lo, ospf_node)
      end
    end

    # @param [Netomox::PseudoDSL::PNode] l3_node Layer3 node
    # @param [Netomox::PseudoDSL::PTermPoint] l3_tp Layer3 term-point of l3_node
    # @param [Netomox::PseudoDSL::PNode] ospf_node OSPF-layer node (add target)
    # @return [Netomox::PseudoDSL::PTermPoint] added term-point (in ospf_node)
    def add_tp_to_ospf_node(l3_node, l3_tp, ospf_node)
      ospf_tp = ospf_node.term_point(l3_tp.name)
      ospf_tp.supports.push([@layer3p.name, l3_node.name, l3_tp.name])
      ospf_tp.attribute = ospf_tp_attr(l3_node, l3_tp)
      ospf_tp
    end

    # @param [Netomox::PseudoDSL::PLinkEdge] l3_edge A edge of L3 link
    # @return [Array(Netomox::PseudoDSL::PNode, Netomox::PseudoDSL::PTermPoint)]
    #   A pair of added ospf node and term-point
    # @raise [StandardError] Node is not found in layer3 network
    def add_ospf_node_tp(l3_edge)
      debug_print "# add ospf node/tp: L3edge: #{l3_edge}"
      l3_node, l3_tp = l3_edge_to_object(l3_edge)
      ospf_node = @network.node(l3_node.name)
      ospf_node.supports.push([@layer3p.name, l3_node.name])
      ospf_node.attribute = ospf_node_attr(l3_node)
      ospf_tp = add_tp_to_ospf_node(l3_node, l3_tp, ospf_node)
      [ospf_node, ospf_tp]
    end

    # @param [Netomox::PseudoDSL::PNode] node1 Source ospf node
    # @param [Netomox::PseudoDSL::PTermPoint] tp1 Source ospf term-point
    # @param [Netomox::PseudoDSL::PNode] node2 Source ospf node
    # @param [Netomox::PseudoDSL::PTermPoint] tp2 Source ospf term-point
    # @return [void]
    def add_ospf_link(node1, tp1, node2, tp2)
      @network.link(node1, tp1, node2, tp2)
      @network.link(node2, tp2, node1, tp1) # bidirectional
    end

    # rubocop:disable Metrics/AbcSize

    # @param [Array<Netomox::PseudoDSL::PLink>] l3_links Layer3 links sourced a segment-node
    # @return [void]
    def add_ospf_node_tp_link(l3_links)
      l3_links.each do |l3_link|
        dst_intf_conf = @ospf_intf_conf.find_record_by_node_intf(l3_link.dst.node, l3_link.dst.tp)
        # ignore destination if it is NOT ospf-enabled node
        next if dst_intf_conf.nil? || !dst_intf_conf.ospf_enabled?

        # add destination node as ospf node (ospf-proc) and connect it to segment node
        n1, tp1 = add_ospf_node_tp(l3_link.src) # segment node
        n2, tp2 = add_ospf_node_tp(l3_link.dst) # ospf-proc node
        add_ospf_node_loopback_tp(l3_link.dst) # segment node doesn't have loopback
        add_ospf_link(n1.name, tp1.name, n2.name, tp2.name)
      end
    end
    # rubocop:enable Metrics/AbcSize

    # @return [void]
    def setup_ospf_topology
      segment_nodes = find_all_l3_segment_type_nodes
      segment_nodes.each do |seg_node|
        links = @layer3p.find_all_links_by_src_name(seg_node.name)
        add_ospf_node_tp_link(links)
      end
    end

    # @param [Netomox::PseudoDSL::PNodeEdge] edge Link edge
    # @return [Array(Netomox::PseudoDSL::PNode, Netomox::PseudoDSL::PTermPoint, OspfProcessConfigurationTableRecord)]
    def find_ospf_node_tp_conf(edge)
      node, tp = @network.find_node_tp_by_edge(edge)
      return [nil, nil, nil] if node.nil? || tp.nil?

      conf = @ospf_intf_conf.find_record_by_node_intf(node.name, tp.name)
      [node, tp, conf]
    end

    # @param [Netomox::PseudoDSL::PNode] other_node Neighbor ospf node of target
    # @param [Netomox::PseudoDSL::PTermPoint] other_tp Neighbor ospf term-point of target
    # @return [Hash] neighbor attribute of ospf term-point
    def tp_neighbor_attr(other_node, other_tp)
      # NOTE: support-tp element is [network, node, tp] array
      stp = other_tp.supports.find { |s| s[0] == @layer3p.name }
      ip_addr = if stp.nil?
                  msg = "Supporting term-point of #{other_node}#{other_tp} for ospf neighbor attribute is not found"
                  @logger.error(msg)
                  ''
                else
                  _, other_stp = @layer3p.find_node_tp_by_name(stp[1], stp[2])
                  other_stp.attribute[:ip_addrs][0]
                end

      { router_id: other_node.attribute[:router_id], ip_addr: }
    end

    # @param [Netomox::PseudoDSL::PTermPoint] target_tp target ospf term-point to add a neighbor attribute
    # @param [Hash] neighbor_attr Neighbor attribute
    # @return [void]
    def add_tp_neighbor_attr(target_tp, neighbor_attr)
      if !target_tp.attribute.key?(:neighbors) || target_tp.attribute[:neighbors].nil?
        target_tp.attribute[:neighbors] = []
      end
      target_tp.attribute[:neighbors].push(neighbor_attr)
    end

    # @param [Netomox::PseudoDSL::PTermPoint] target_tp Update target ospf term-point
    # @param [Array<Netomox::PseudoDSL::PLinkEdge>] other_edges neighbor candidate ospf term-points
    # @return [void]
    def listing_neighbors_and_update(target_tp, other_edges)
      other_edges.each do |other_edge|
        other_node, other_tp, other_conf = find_ospf_node_tp_conf(other_edge)
        next if other_conf.nil? || !other_conf.ospf_active?

        add_tp_neighbor_attr(target_tp, tp_neighbor_attr(other_node, other_tp))
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
