# frozen_string_literal: true

require 'grape'

module NetomoxExp
  module ApiRoute
    # api /nodes
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

        ns_converter = ns_converter_wo_topology(network)
        nodes = nw.nodes.map
        nodes = nw.nodes.select { |n| n.attribute.node_type == params[:node_type] } if params.key?(:node_type)

        # response
        nodes.map do |node|
          {
            node: node.name,
            reverse: ns_converter.node_name_table.reverse_lookup(node.name),
            alias: ns_converter.node_name_table.find_l1_alias(node.name),
            attribute: node.attribute.to_data
          }
        end
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

        ns_converter = ns_converter_wo_topology(network)
        nodes = nw.nodes
        nodes = nw.nodes.select { |n| n.attribute.node_type == params[:node_type] } if params.key?(:node_type)

        # response
        nodes.map do |node|
          {
            node: node.name,
            reverse: ns_converter.node_name_table.reverse_lookup(node.name),
            alias: ns_converter.node_name_table.find_l1_alias(node.name),
            attribute: node.attribute.to_data,
            interfaces: node.termination_points.map do |tp|
              {
                interface: tp.name,
                reverse: ns_converter.tp_name_table.reverse_lookup(node.name, tp.name)[1],
                alias: ns_converter.tp_name_table.find_l1_alias(node.name, tp.name),
                attribute: tp.attribute.to_data
              }
            end
          }
        end
      end
    end
  end
end
