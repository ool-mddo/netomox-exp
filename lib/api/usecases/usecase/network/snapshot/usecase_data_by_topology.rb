# frozen_string_literal: true

require 'grape'
require 'lib/usecase_deliverer/iperf_command_generator'
require 'lib/usecase_deliverer/external_as_topology/bgp_as_data_builder'

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
        builder = UsecaseDeliverer::BgpAsDataBuilder.new(usecase, usecase_params, usecase_flows, int_as_topology)

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
        l3_endpoints = fetch_l3_endpoints(network, snapshot)
        generator = UsecaseDeliverer::IperfCommandGenerator.new(usecase_params, usecase_flows, l3_endpoints)
        generator.generate_iperf_commands
      end
    end
  end
end
