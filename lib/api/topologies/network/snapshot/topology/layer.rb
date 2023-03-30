# frozen_string_literal: true

require 'grape'
require 'lib/convert_topology/batfish_converter'
require 'lib/convert_topology/containerlab_converter'

module NetomoxExp
  module ApiRoute
    # namespace /layer
    class Layer < Grape::API
      params do
        requires :layer, type: String, desc: 'Network layer'
      end
      # rubocop:disable Metrics/BlockLength
      resource ':layer' do
        desc 'convert layer data to batfish layer1_topology.json'
        get 'batfish_layer1_topology' do
          network, snapshot, layer = %i[network snapshot layer].map { |key| params[key] }
          topology_data = read_topology_file(network, snapshot)
          ns_converter = ns_converter_wo_topology(network)
          bf_converter = BatfishConverter.new(topology_data, layer, ns_converter)
          # response
          bf_converter.convert
        end

        desc 'convert layer data to container-lab topology json'
        params do
          optional :env_name, type: String, desc: 'Environment name (for container-lab)', default: 'emulated'
        end
        get 'containerlab_topology' do
          network, snapshot, layer, env_name = %i[network snapshot layer env_name].map { |key| params[key] }
          topology_data = read_topology_file(network, snapshot)
          ns_converter = ns_converter_wo_topology(network)
          clab_converter = ContainerLabConverter.new(topology_data, layer, ns_converter, { env_name: })
          # response
          clab_converter.convert
        end

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
              alias: ns_converter.node_name_table.find_l1_alias(node.name),
              attribute: node.attribute.to_data,
              interfaces: node.termination_points.map do |tp|
                {
                  interface: tp.name,
                  alias: ns_converter.tp_name_table.find_l1_alias(node.name, tp.name),
                  attribute: tp.attribute.to_data
                }
              end
            }
          end
        end
      end
      # rubocop:enable Metrics/BlockLength
    end
  end
end
