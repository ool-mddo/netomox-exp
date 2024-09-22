# frozen_string_literal: true

require 'httpclient'
require 'json'
require 'netomox'

module NetomoxExp
  # patch for helpers (see helpers.rb)
  module Helpers
    # usecases dir for usecase data operation
    USECASE_DIR = ENV.fetch('MDDO_USECASES_DIR', '/mddo/usecases')

    # @param [String] usecase Usecase name
    # @param [String] network Network name
    # @param [String] flow_file File name of a flow data
    # @return [Array<Hash>] flow data
    def read_flow_data(usecase, network, flow_file)
      flow_file_path = File.join(USECASE_DIR, usecase, network, 'flows', "#{flow_file}.csv")
      error!("Not found usecase flow-data: #{flow_file_path}", 404) unless File.exist?(flow_file_path)

      read_csv_file(flow_file_path)
    end

    # @param [String] usecase Usecase name
    # @param [String] network Network name
    # @return [Hash] usecase params
    def read_params(usecase, network)
      param_file_path = File.join(USECASE_DIR, usecase, network, 'params.yaml')
      error!("Not found usecase params: #{param_file_path}", 404) unless File.exist?(param_file_path)

      read_yaml_file(param_file_path)
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
end
