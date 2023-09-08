# frozen_string_literal: true

require 'grape'

module NetomoxExp
  module ApiRoute
    # api config_params
    class ConfigParams < Grape::API
      desc 'Get all interface parameters for generate config files'
      params do
        optional :node_type, type: String, desc: 'Node type (segment/node/endpoint)'
      end
      get 'config_params' do
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
            name: node.name,
            agent_name: ns_converter.node_name.find_l1_alias(node.name)['l1_agent'],
            type: node.attribute&.node_type,
            if_list: node.termination_points.map do |tp|
              {
                name: tp.name,
                agent_name: ns_converter.tp_name.find_l1_alias(node.name, tp.name)['l1_agent'],
                ipv4: tp.attribute.empty? ? nil : tp.attribute&.ip_addrs&.[](0),
                description: tp.attribute.empty? ? nil : tp.attribute&.description,
                original_if: ns_converter.tp_name.reverse_lookup(node.name, tp.name)[1]
              }
            end
          }
        end
      end
    end
  end
end
