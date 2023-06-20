# frozen_string_literal: true

require 'grape'

module NetomoxExp
  module ApiRoute
    # api /nodes, /interfaces
    class LayerObjects < Grape::API
      desc 'Get all nodes in the layer'
      params do
        optional :node_type, type: String, desc: 'Node type (segment/node/endpoint)'
      end
      get 'nodes' do
        network, snapshot, layer = %i[network snapshot layer].map { |key| params[key] }
        nws = read_topology_instance(network, snapshot)
        nw = nws.find_network(layer)
        error!("#{network}/#{snapshot}/#{layer} not found", 404) if nw.nil?

        nodes = nw.nodes
        nodes = nw.nodes.select { |n| n.attribute.node_type == params[:node_type] } if params.key?(:node_type)

        # response
        {
          network: nw.name,
          attribute: nw.attribute.to_data,
          nodes: convert_layer_nodes(network, nodes)
        }
      end

      desc 'Get all interfaces in the layer'
      params do
        optional :node_type, type: String, desc: 'Node type (segment/node/endpoint)'
      end
      get 'interfaces' do
        network, snapshot, layer = %i[network snapshot layer].map { |key| params[key] }
        nws = read_topology_instance(network, snapshot)
        nw = nws.find_network(layer)
        error!("#{network}/#{snapshot}/#{layer} not found", 404) if nw.nil?

        nodes = nw.nodes
        nodes = nw.nodes.select { |n| n.attribute.node_type == params[:node_type] } if params.key?(:node_type)

        # response
        {
          network: nw.name,
          attribute: nw.attribute.to_data,
          nodes: convert_layer_interfaces(network, nodes)
        }
      end
    end
  end
end
