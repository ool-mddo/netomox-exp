# frozen_string_literal: true

require_relative 'topology_converter_base'

module NetomoxExp
  # topology dat converter for batfish
  class BatfishConverter < TopologyConverterBase
    # @return [Hash] layer1-topology data for batfish
    def convert
      { 'edges' => link_data }
    end

    private

    # @param [Netomox::Topology::TpRef] edge Link edge
    # @return [Hash]
    def edge_to_hash(edge)
      # NOTE: interface (tp) name is unsafe
      {
        'hostname' => safe_node_name(edge.node_ref),
        'interfaceName' => edge.tp_ref
      }
    end

    # @return [Array<Hash>] link data
    def link_data
      @src_network.links.map do |link|
        # NOTE: batfish layer1_topology.json needs bidirectional link data
        {
          'node1' => edge_to_hash(link.source),
          'node2' => edge_to_hash(link.destination)
        }
      end
    end
  end
end
