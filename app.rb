# frozen_string_literal: true

require 'fileutils'
require 'grape'
require 'httpclient'
require 'json'

# Directories
CONFIGS_DIR = ENV.fetch('MDDO_CONFIGS_DIR', 'configs')
MODELS_DIR = ENV.fetch('MDDO_MODELS_DIR', 'models')
NETOVIZ_DIR = ENV.fetch('MDDO_NETOVIZ_MODEL_DIR', 'netoviz_model')
MODEL_DEFS_DIR = 'model_defs'
# Batfish-wrapper
BATFISH_WRAPPER_HOST = 'batfish-wrapper:5000'
BFW_CLIENT = HTTPClient.new
BFW_CLIENT.receive_timeout = 60 * 60 * 4 # 60sec * 60min * 4h

def post_bfw(api_path, data)
  header = { 'Content-Type' => 'application/json' }
  body = JSON.generate(data)
  url = "http://#{BATFISH_WRAPPER_HOST}/#{api_path}"
  puts "- POST: #{url}, data=#{data}"
  BFW_CLIENT.post url, body:, header:
end

# Netomox REST API definition
class NetomoxRestApi < Grape::API
  format :json

  # rubocop:disable Metrics/BlockLength
  namespace 'models' do
    params do
      requires :network, type: String, desc: 'Network name'
    end

    resource ':network' do
      delete do
        network_dir = File.join(MODELS_DIR, params[:network])
        FileUtils.rmtree(network_dir)
        FileUtils.mkdir_p(network_dir)
        {
          method: 'DELETE',
          path: network_dir
        }
      end

      params do
        requires :snapshot, type: String, desc: 'Snapshot name'
      end

      resource ':snapshot' do
        desc 'Clean models directory'
        delete do
          snapshot_dir = File.join(MODELS_DIR, params[:network], params[:snapshot])
          FileUtils.rmtree(File.join(snapshot_dir))
          FileUtils.mkdir_p(snapshot_dir)
          {
            method: 'DELETE',
            path: snapshot_dir
          }
        end

        desc 'Make snapshot patterns'
        params do
          optional :phy_ss_only, type: Boolean
          optional :off_node, type: String
          optional :off_intf_re, type: String
        end

        post 'patterns' do
          phy_ss_only = params.key?(:phy_ss_only) ? params[:phy_ss_only] : false
          off_node = params.key?(:off_node) ? params[:off_node] : ''
          off_intf_re = !off_node.empty? && params.key?(:off_intf_re) ? params[:off_intf_re] : ''
          response = {
            method: 'POST',
            path: "models/#{params[:network]}/#{params[:snapshot]}/patterns"
          }

          if phy_ss_only
            snapshot_dir = File.join(CONFIGS_DIR, params[:network], params[:snapshot])
            pattern_file = File.join(snapshot_dir, 'snapshot_patterns.json')
            FileUtils.rm_f(pattern_file)
            response[:result] = {}
            return response
          end

          opt = {}
          if off_node
            opt['node'] = off_node
            opt['interface_regexp'] = off_intf_re unless off_intf_re.empty?
          end

          result = post_bfw("api/networks/#{params[:network]}/snapshots/#{params[:snapshot]}/patterns", opt)
          response[:result] = JSON.parse(result.body)
          response
        end
      end
    end
    # rubocop:enable Metrics/BlockLength
  end
end
