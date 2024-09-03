# frozen_string_literal: true

require 'grape'
require 'json'
require 'httpclient'
require 'lib/usecase_deliverer/pni/iperf_command_generator'
require 'lib/usecase_deliverer/pni/external_as_topology/bgp_as_data_builder'
require_relative 'usecase_helpers'

module NetomoxExp
  module ApiRoute
    # usecase parameter handling
    class UsecaseDataOps < Grape::API
      desc 'Get external-AS topology'
      params do
        requires :network, type: String, desc: 'Network name'
        optional :snapshot, type: String, desc: 'Snapshot name', default: 'original_asis'
      end
      get 'external_as_topology' do
        usecase, network, snapshot = %i[usecase network snapshot].map { |key| params[key] }

        usecase_flows = read_flow_data(usecase)
        usecase_params = read_params(usecase)
        int_as_topology = fetch_topology_object(network, snapshot)
        ext_as_topology_builder = BgpASDataBuilder.new(usecase_params, usecase_flows, int_as_topology)

        # response
        ext_as_topology_builder.build_topology
      end

      desc 'Get iperf commands'
      params do
        requires :network, type: String, desc: 'Network name'
        requires :snapshot, type: String, desc: 'Snapshot name'
      end
      get 'iperf_commands' do
        # # NOTE: proxy to batfish-wrapper, because script to generate iperf commands is written in python...
        # get_bfw_iperf_commands(params[:usecase])

        flow_data_list = read_flow_data(params[:usecase])
        l3endpoint_list = fetch_l3endpoint_list(params[:network], params[:snapshot])
        iperf_command_generator = UsecaseDeliverer::IperfCommandGenerator.new(flow_data_list, l3endpoint_list)
        iperf_command_generator.generate_iperf_commands
      end

      desc 'Get flow data (csv -> json)'
      get 'flow_data' do
        read_flow_data(params[:usecase])
      end

      desc 'Get usecase params (yaml -> json)'
      get 'params' do
        read_params(params[:usecase])
      end
    end
  end
end
