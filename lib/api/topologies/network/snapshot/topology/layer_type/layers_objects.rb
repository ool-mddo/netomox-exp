# frozen_string_literal: true

require 'lib/api/rest_api_base'

module NetomoxExp
  module ApiRoute
    # fetch/filter multiple layer parameters
    class LayersObjects < RestApiBase
      # multiple layer in several layers (networks) in topology data (RFC8345 based json)
      desc 'Get topology data (multiple layers by network type'
      get do
        network, snapshot, layer_type = %i[network snapshot layer_type].map { |key| params[key] }
        nws = read_topology_instance(network, snapshot)
        found_nws = nws.find_all_networks_by_type(convert_layer_type(layer_type))

        # response
        found_nws.map(&:to_data)
      end

      # api /nodes, /interfaces

      params do
        optional :node_name, type: String, desc: 'Node name'
        optional :node_type, type: String, desc: 'Node type (segment/node/endpoint)'
        optional :exc_node_type, type: String, desc: 'Exclude node type (segment/node/endpoint)'
        mutually_exclusive :node_name, :node_type, :exc_node_type
      end
      get 'nodes' do
        network, snapshot, layer_type = %i[network snapshot layer_type].map { |key| params[key] }
        nws = read_topology_instance(network, snapshot)
        found_nws = nws.find_all_networks_by_type(convert_layer_type(layer_type))

        # response
        found_nws.map do |nw|
          nodes = nw.nodes
          nodes.select! { |n| n.name == params[:node_name] } if params.key?(:node_name)
          nodes.select! { |n| n.attribute.node_type == params[:node_type] } if params.key?(:node_type)
          nodes.reject! { |n| n.attribute.node_type == params[:exc_node_type] } if params.key?(:exc_node_type)
          {
            network: nw.name,
            attribute: nw.attribute.to_data,
            nodes: convert_layer_nodes(network, nodes)
          }
        end
      end

      params do
        optional :node_name, type: String, desc: 'Node name'
        optional :node_type, type: String, desc: 'Node type (segment/node/endpoint)'
        optional :exc_node_type, type: String, desc: 'Exclude node type (segment/node/endpoint)'
        mutually_exclusive :node_name, :node_type, :exc_node_type
      end
      get 'interfaces' do
        network, snapshot, layer_type = %i[network snapshot layer_type].map { |key| params[key] }
        nws = read_topology_instance(network, snapshot)
        found_nws = nws.find_all_networks_by_type(convert_layer_type(layer_type))

        # response
        found_nws.map do |nw|
          nodes = nw.nodes
          nodes.select! { |n| n.name == params[:node_name] } if params.key?(:node_name)
          nodes.select! { |n| n.attribute.node_type == params[:node_type] } if params.key?(:node_type)
          nodes.reject! { |n| n.attribute.node_type == params[:exc_node_type] } if params.key?(:exc_node_type)
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
