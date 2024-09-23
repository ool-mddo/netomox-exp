# frozen_string_literal: true

require 'grape'
require 'lib/api/usecases/usecase/usecase_helpers'
require 'lib/usecase_deliverer/pni/iperf_command_generator'
require 'lib/usecase_deliverer/pni/external_as_topology/bgp_as_data_builder'

module NetomoxExp
  module ApiRoute
    # usecase data based on topology data
    class UsecaseDataByTopology < Grape::API
      desc 'Get external-AS topology'
      params do
        requires :flow_data, type: String, desc: 'File name of a flow data'
      end
      get 'external_as_topology' do
        usecase, network, snapshot, flow_data = %i[usecase network snapshot flow_data].map { |key| params[key] }

        usecase_flows = read_flow_data(usecase, network, flow_data)
        usecase_params = read_params(usecase, network)
        int_as_topology = fetch_topology_object(network, snapshot)
        builder = UsecaseDeliverer::BgpAsDataBuilder.new(usecase_params, usecase_flows, int_as_topology)

        # response
        builder.build_topology
      end

      desc 'Get iperf commands'
      params do
        requires :flow_data, type: String, desc: 'File name of a flow data'
      end
      get 'iperf_commands' do
        usecase, network, snapshot, flow_data = %i[usecase network snapshot flow_data].map { |key| params[key] }

        usecase_flows = read_flow_data(usecase, network, flow_data)
        usecase_params = read_params(usecase, network)
        l3endpoint_list = fetch_l3endpoint_list(network, snapshot)
        generator = UsecaseDeliverer::IperfCommandGenerator.new(usecase_params, usecase_flows, l3endpoint_list)
        generator.generate_iperf_commands
      end
    end
  end
end
