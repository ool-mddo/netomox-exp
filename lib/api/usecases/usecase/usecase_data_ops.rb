# frozen_string_literal: true

require 'grape'
require 'json'
require 'httpclient'
require 'open3'

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

    # request to batfish-wrapper to call python script
    # @param [String] usecase Usecase name
    # @return [Object] result data
    def get_bfw_iperf_commands(usecase)
      bfw_host = ENV.fetch('BATFISH_WRAPPER_HOST', 'batfish-wrapper:5000')
      http_client = HTTPClient.new
      response = http_client.get("http://#{bfw_host}/usecases/#{usecase}/iperf_commands")
      error!('Unexpected batfish-wrapper call', 500) unless response.status / 100 == 2

      JSON.parse(response.body)
    end

    # @param [String] usecase Usecase name
    # @param [String] filename File name (to save)
    # @param [Object] data
    # @return [void]
    def save_json_file_for_usecase(usecase, filename, data)
      file_dir = File.join(USECASE_DIR, usecase)
      error!("Usecase dir: #{file_dir} is not found", 404) unless Dir.exist? file_dir

      file_path = File.join(file_dir, filename)
      File.write(file_path, JSON.generate(data))
    end
  end

  module ApiRoute
    # usecase parameter handling
    class UsecaseDataOps < Grape::API
      desc 'Get external-AS topology'
      params do
        requires :network, type: String, desc: 'Network name'
      end
      get 'external_as_topology' do
        usecase, network = %i[usecase network].map { |key| params[key] }

        ucf = usecase_file(usecase)
        error!("Not found usecase params: #{ucf[:params_file]}", 404) unless File.exist?(ucf[:params_file])
        error!("Not found usecase flowdata: #{ucf[:flow_data_file]}", 404) unless File.exist?(ucf[:flow_data_file])

        cmd = "ruby #{ucf[:ext_as_file]} -n #{network} -f #{ucf[:flow_data_file]} -p #{ucf[:params_file]}"
        output, _status = Open3.capture3(cmd)

        # response
        JSON.parse(output)
      end

      desc 'Get iperf commands'
      get 'iperf_commands' do
        # NOTE: proxy to batfish-wrapper, because script to generate iperf commands is written in python...
        get_bfw_iperf_commands(params[:usecase])
      end

      desc 'Get flow data (csv -> json)'
      get 'flow_data' do
        usecase = params[:usecase]

        ucf = usecase_file(usecase)
        error!("Not found usecase flowdata: #{ucf[:flow_data_file]}", 404) unless File.exist?(ucf[:flow_data_file])

        # response
        read_csv_file(ucf[:flow_data_file])
      end

      desc 'Get usecase params (yaml -> json)'
      get 'params' do
        usecase = params[:usecase]

        ucf = usecase_file(usecase)
        error!("Not found usecase params: #{ucf[:params_file]}", 404) unless File.exist?(ucf[:params_file])

        # response
        read_yaml_file(ucf[:params_file])
      end

      desc 'Post static-route data'
      params do
        requires :static_routes, type: Array, desc: 'Static-route data'
      end
      post 'static_routes' do
        usecase = params[:usecase]
        static_routes = params[:static_routes]

        save_json_file_for_usecase(usecase, '_static_routes.json', static_routes)
        # response
        {}
      end
    end
  end
end
