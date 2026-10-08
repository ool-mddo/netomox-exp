# frozen_string_literal: true

require 'lib/convert_namespace/namespace_converter'

# helpers to build namespace converters from fixtures
module ConverterHelper
  module_function

  # @param [Hash] topology_data original topology
  # @return [NetomoxExp::ConvertNamespace::NamespaceConverter]
  def ns_converter_for(topology_data)
    NetomoxExp::ConvertNamespace::NamespaceConverter.new.tap { |c| c.load_origin_topology(topology_data) }
  end

  # @return [Array<Hash>] links of the network of RFC8345 topology
  def links_of(topology_data, network_id)
    nw = topology_data['ietf-network:networks']['network'].find { |n| n['network-id'] == network_id }
    nw['ietf-network-topology:link']
  end

  # @return [Array<Hash>] nodes of the network of RFC8345 topology
  def nodes_of(topology_data, network_id)
    nw = topology_data['ietf-network:networks']['network'].find { |n| n['network-id'] == network_id }
    nw['node']
  end
end
