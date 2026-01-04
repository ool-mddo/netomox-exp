# frozen_string_literal: true

require 'lib/api/rest_api_base'

module NetomoxExp
  module ApiRoute
    # fetch/filter single layer parameters
    class LayerObjects < RestApiBase
      # layer itself: a (network) layer in topology data (RFC8345 based json)
      desc 'Get topology data (specified layer)'
      get do
        network, snapshot, layer = %i[network snapshot layer].map { |key| params[key] }
        nws = read_topology_instance(network, snapshot)
        nw = nws.find_network(layer)
        error!("#{network}/#{snapshot}/#{layer} not found", 404) if nw.nil?

        # response
        nw.to_data
      end

      # api /nodes, /interfaces

      desc 'Get all nodes in the layer'
      params do
        optional :node_name, type: String, desc: 'Node name'
        optional :node_type, type: String, desc: 'Node type (segment/node/endpoint)'
        optional :exc_node_type, type: String, desc: 'Exclude node type (segment/node/endpoint)'
        mutually_exclusive :node_name, :node_type, :exc_node_type
      end
      get 'nodes' do
        network, snapshot, layer = %i[network snapshot layer].map { |key| params[key] }
        nws = read_topology_instance(network, snapshot)
        nw = nws.find_network(layer)
        error!("#{network}/#{snapshot}/#{layer} not found", 404) if nw.nil?

        nodes = nw.nodes
        nodes.select! { |n| n.name == params[:node_name] } if params.key?(:node_name)
        nodes.select! { |n| n.attribute.node_type == params[:node_type] } if params.key?(:node_type)
        nodes.reject! { |n| n.attribute.node_type == params[:exc_node_type] } if params.key?(:exc_node_type)

        # response
        {
          network: nw.name,
          attribute: nw.attribute.to_data,
          nodes: convert_layer_nodes(network, nodes)
        }
      end

      desc 'Get all interfaces in the layer'
      params do
        optional :node_name, type: String, desc: 'Node name'
        optional :node_type, type: String, desc: 'Node type (segment/node/endpoint)'
        optional :exc_node_type, type: String, desc: 'Exclude node type (segment/node/endpoint)'
        mutually_exclusive :node_name, :node_type, :exc_node_type
      end
      get 'interfaces' do
        network, snapshot, layer = %i[network snapshot layer].map { |key| params[key] }
        nws = read_topology_instance(network, snapshot)
        nw = nws.find_network(layer)
        error!("#{network}/#{snapshot}/#{layer} not found", 404) if nw.nil?

        nodes = nw.nodes
        nodes.select! { |n| n.name == params[:node_name] } if params.key?(:node_name)
        nodes.select! { |n| n.attribute.node_type == params[:node_type] } if params.key?(:node_type)
        nodes.reject! { |n| n.attribute.node_type == params[:exc_node_type] } if params.key?(:exc_node_type)

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
