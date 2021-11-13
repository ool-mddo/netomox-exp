# frozen_string_literal: true

require_relative '../bf_common/pseudo_model'
require_relative 'csv/node_props_table'
require_relative 'csv/edges_layer1_table'

# L1 data builder
class L1DataBuilder < DataBuilderBase
  # @param [String] target Target network (config) data name
  def initialize(target)
    super()
    @node_props = NodePropsTable.new(target)
    @l1_edges = EdgesLayer1Table.new(target)
  end

  # @return [PNetworks] Networks contains only layer1 network topology
  def make_networks
    @network = PNetwork.new('layer1')
    make_nodes
    make_links
    @networks.push(@network)
    @networks
  end

  private

  def make_nodes
    @node_props.each do |node_prop|
      l1_node = @network.node(node_prop.node)
      node_prop.physical_interfaces.map { |intf| l1_node.term_point(intf) }
    end
  end

  def make_links
    @l1_edges.each do |edge|
      @network.link(edge.src.node, edge.src.interface, edge.dst.node, edge.dst.interface)
    end
  end
end
