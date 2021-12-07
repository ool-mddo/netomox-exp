# frozen_string_literal: true

require_relative '../bf_common/pseudo_model'
require_relative 'csv/edges_layer1_table'
require_relative 'csv/interface_prop_table'

# L1 data builder
class L1DataBuilder < DataBuilderBase
  # @param [String] target Target network (config) data name
  def initialize(target:, debug: false)
    super(debug: debug)
    @l1_edges = EdgesLayer1Table.new(target)
    @intf_props = InterfacePropertiesTable.new(target)
  end

  # @return [PNetworks] Networks contains only layer1 network topology
  def make_networks
    @network = @networks.network('layer1')
    @network.type = Netomox::NWTYPE_MDDO_L1
    setup_node_tp_link
    @networks
  end

  private

  # @param [PLink] l1_link Layer1 link
  # @return [Boolean] true if the link is LAG link
  def lag_link?(l1_link)
    src_intf_props = @intf_props.find_record_by_node_intf(l1_link.src.node, l1_link.src.interface)
    dst_intf_props = @intf_props.find_record_by_node_intf(l1_link.dst.node, l1_link.dst.interface)
    src_intf_props && dst_intf_props && src_intf_props.lag_parent? && dst_intf_props.lag_parent?
  end

  # @param [EdgeBase] edge LAG port
  # @return [Array<String>] Interfaces of the LAG member
  def lag_members(edge)
    intf_props = @intf_props.find_record_by_node_intf(edge.node, edge.interface)
    raise StandardError("LAG member props not found: #{edge}") unless intf_props

    intf_props.lag_member_interfaces
  end

  # @param [String] node_name Node name
  # @param [String] intf_name Interface name
  # @return [void]
  def add_node_tp(node_name, intf_name)
    node = @network.node(node_name)
    tp = node.term_point(intf_name)
    tp_rec = @intf_props.find_record_by_node_intf(node_name, intf_name)
    tp.attribute = { description: tp_rec.description || '' } if tp_rec # nil to '' for intf without description
  end

  # @param [String] src_node Source node name
  # @param [String] src_intf Source interface name
  # @param [String] dst_node Destination node name
  # @param [String] dst_intf Destination interface name
  # @return [void]
  def add_node_tp_link(src_node, src_intf, dst_node, dst_intf)
    add_node_tp(src_node, src_intf)
    add_node_tp(dst_node, dst_intf)
    @network.link(src_node, src_intf, dst_node, dst_intf)
  end

  # @param [EdgesLayer1TableRecord] l1_link Layer1 link record
  # @return [void]
  def add_node_tp_link_for_lag_link(l1_link)
    src_lag_members = lag_members(l1_link.src)
    dst_lag_members = lag_members(l1_link.dst)
    # NOTE: if the `edges_layer1` table is generated by batfish `edges(layer1)` query,
    #   the table does NOT have connection information about LAG-members.
    #   make it a pair according to its sequence of LAG members list.
    src_lag_members.each_with_index do |src_intf, i|
      add_node_tp_link(l1_link.src.node, src_intf, l1_link.dst.node, dst_lag_members[i])
    end
  end

  # make links
  # @return [void]
  def setup_node_tp_link
    # NOTE: Layer1 edge data is bidirectional link.
    #   A physical link is expressed two unidirectional link record.
    @l1_edges.each do |l1_link|
      # NOTE: if the `edges_layer1` is a result of batfish `edges(layer1)` query.
      #   when the table is a layer1_topology.json -converted data,
      #   it does not have LAG link (physical link ONLY)
      if lag_link?(l1_link)
        add_node_tp_link_for_lag_link(l1_link)
        next
      end

      add_node_tp_link(l1_link.src.node, l1_link.src.interface, l1_link.dst.node, l1_link.dst.interface)
    end
  end
end
