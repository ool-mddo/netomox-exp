# frozen_string_literal: true

require 'grape'

module NetomoxExp
  module ApiRoute
    # api /nodes, /interfaces
    class LayersObjects < Grape::API
      params do
        optional 'node_type', type: String, desc: 'Node type (segment/node/endpoint)'
      end
      get 'nodes' do
        network, snapshot, layer_type = %i[network snapshot layer_type].map { |key| params[key] }
        nws = read_topology_instance(network, snapshot)
        found_nws = nws.find_all_networks_by_type(convert_layer_type(layer_type))

        # response
        found_nws.map do |nw|
          nodes = nw.nodes
          nodes = nw.nodes.select { |n| n.attribute.node_type == params[:node_type] } if params.key?(:node_type)
          {
            network: nw.name,
            attribute: nw.attribute.to_data,
            nodes: convert_layer_nodes(network, nodes)
          }
        end
      end

      params do
        optional 'node_type', type: String, desc: 'Node type (segment/node/endpoint)'
      end
      get 'interfaces' do
        network, snapshot, layer_type = %i[network snapshot layer_type].map { |key| params[key] }
        nws = read_topology_instance(network, snapshot)
        found_nws = nws.find_all_networks_by_type(convert_layer_type(layer_type))

        # response
        found_nws.map do |nw|
          nodes = nw.nodes
          nodes = nw.nodes.select { |n| n.attribute.node_type == params[:node_type] } if params.key?(:node_type)
          {
            network: nw.name,
            attribute: nw.attribute.to_data,
            nodes: convert_layer_interfaces(network, nodes)
          }
        end
      end
    end
  end
end
