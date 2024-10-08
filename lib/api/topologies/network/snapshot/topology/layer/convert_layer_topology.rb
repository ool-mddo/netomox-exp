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
        bf_converter = ConvertTopology::BatfishConverter.new(topology_data, layer, ns_converter)

        # response
        bf_converter.convert
      end

      desc 'convert layer data to container-lab topology json'
      params do
        optional :env_name, type: String, desc: 'Environment name (for container-lab)', default: 'emulated'
        optional :bind_license, type: String, desc: 'Router bind configs (like "license.key:/tmp/license.key")'
        optional :license, type: String, desc: 'Router license file path for container'
        requires :image, type: String, desc: 'Router image name'
      end
      get 'containerlab_topology' do
        network, snapshot, layer = %i[network snapshot layer].map { |key| params[key] }

        topology_data = read_topology_file(network, snapshot)
        ns_converter = ns_converter_wo_topology(network)
        opts = %i[env_name bind_license license image].select { |key| params.key?(key) }
                                                      .to_h { |key| [key, params[key]] }
        clab_converter = ConvertTopology::ContainerLabConverter.new(topology_data, layer, ns_converter, opts)

        # response
        clab_converter.convert
      end
    end
  end
end
