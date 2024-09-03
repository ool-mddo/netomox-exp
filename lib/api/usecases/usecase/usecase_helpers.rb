# frozen_string_literal: true

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
end
