# frozen_string_literal: true

require 'grape'
require 'json'
require 'httpclient'
require 'lib/usecase_deliverer/pni/iperf_command_generator'
require 'lib/usecase_deliverer/pni/external_as_topology/bgp_as_data_builder'

module NetomoxExp
  # patch for helpers (see helpers.rb)
  module Helpers
    # usecases dir for usecase data operation
    USECASE_DIR = ENV.fetch('MDDO_USECASES_DIR', '/mddo/usecases')

    # @param [String] usecase Usecase name
    # @return [Hash] file path data for usecase
    def usecase_file(usecase)
      common_usecase = usecase.split('_')[0] # "pni" for "pni_te", "pni_addlink" usecase
      {
        ext_as_file: File.join(USECASE_DIR, common_usecase, 'external_as_topology', 'main.rb'),
        params_file: File.join(USECASE_DIR, usecase, 'params.yaml'),
        flow_data_file: File.join(USECASE_DIR, usecase, 'flowdata.csv')
      }
    end

    # @param [String] usecase Usecase name
    # @return [Array<Hash>] flow data
    def read_flow_data(usecase)
      ucf = usecase_file(usecase)
      error!("Not found usecase flowdata: #{ucf[:flow_data_file]}", 404) unless File.exist?(ucf[:flow_data_file])

      read_csv_file(ucf[:flow_data_file])
    end

    # param [String] usecase Usecase name
    # @return [Hash] usecase params
    def read_params(usecase)
      ucf = usecase_file(usecase)
      error!("Not found usecase params: #{ucf[:params_file]}", 404) unless File.exist?(ucf[:params_file])

      read_yaml_file(ucf[:params_file])
    end

    # @param [String] network Network name
    # @param [String] snapshot Snapshot name
    # @return [Array<Hash>] L3 endpoint list
    def fetch_l3endpoint_list(network, snapshot)
      http_client = HTTPClient.new
      url = "topologies/#{network}/#{snapshot}/topology/layer3/interfaces"
      params = { node_type: 'endpoint' }
      # NOTE: query myself: port number was hard-coded
      response = http_client.get("http://localhost:9292/#{url}", params)
      error!("Unexpected call for #{url}", 500) unless response.status / 100 == 2

      layer3 = JSON.parse(response.body)
      layer3['nodes']
    end

    # @param [String] network Network name
    # @param [String] snapshot Snapshot name
    # @return [Netomox::Topology::Networks] topology data
    def fetch_topology_object(network, snapshot)
      http_client = HTTPClient.new
      url = "topologies/#{network}/#{snapshot}/topology"
      # NOTE: query myself: port number was hard-coded
      response = http_client.get("http://localhost:9292/#{url}")
      error!("Unexpected call for #{url}", 500) unless response.status / 100 == 2

      Netomox::Topology::Networks.new(JSON.parse(response.body))
    end
  end

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
