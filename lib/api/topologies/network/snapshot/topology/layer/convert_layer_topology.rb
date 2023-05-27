# frozen_string_literal: true

require 'grape'
require 'lib/convert_topology/batfish_converter'
require 'lib/convert_topology/containerlab_converter'

module NetomoxExp
  module ApiRoute
    # api that convert a layer topology to another another data
    class ConvertLayerTopology < Grape::API
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
    end
  end
end
