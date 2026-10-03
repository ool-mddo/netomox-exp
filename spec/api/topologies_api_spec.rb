# frozen_string_literal: true

require 'app'

RSpec.describe 'topologies API' do
  include ApiHelper

  let(:nw) { 'mddo-fw' }
  let(:ss) { 'original_asis' }
  let(:snapshot_dir) { File.join(ApiHelper::TOPOLOGIES_DIR, nw, ss) }

  before { prepare_dirs }

  describe 'POST/GET /topologies/:nw/:ss/topology' do
    it 'generates topology from batfish query results and saves it' do
      post_json "/topologies/#{nw}/#{ss}/topology"
      expect(last_response.status).to eq 201
      expect(json_body['ietf-network:networks']['network'].map { |n| n['network-id'] })
        .to include('layer1', 'layer2', 'layer3')
      expect(File.exist?(File.join(snapshot_dir, 'topology.json'))).to be true
    end

    it 'registers posted topology data as it is' do
      data = FixtureHelper.fw_topology
      register_topology(nw, 'registered', data)
      expect(last_response.status).to eq 201
      get "/topologies/#{nw}/registered/topology"
      expect(last_response.status).to eq 200
      expect(json_body).to eq data
    end

    it 'returns 404 for unknown snapshot' do
      get "/topologies/#{nw}/unknown/topology"
      expect(last_response.status).to eq 404
    end
  end

  describe 'layer APIs' do
    before { register_topology(nw, ss, FixtureHelper.fw_topology) }

    it 'GET /topology/:layer returns a layer' do
      get "/topologies/#{nw}/#{ss}/topology/layer3"
      expect(last_response.status).to eq 200
      expect(json_body['network-id']).to eq 'layer3'
    end

    it 'GET /topology/:layer returns 404 for unknown layer' do
      get "/topologies/#{nw}/#{ss}/topology/layer99"
      expect(last_response.status).to eq 404
    end

    it 'matches /layer_type_:layer_type before /:layer' do
      post_json "/topologies/#{nw}/#{ss}/ns_convert_table"
      # if matched as /:layer, 404 is returned (layer named "layer_type_layer3" does not exist)
      get "/topologies/#{nw}/#{ss}/topology/layer_type_layer3/nodes"
      expect(last_response.status).to eq 200
    end

    it 'GET /topology/:layer/nodes filters by node_type (needs ns_convert_table)' do
      post_json "/topologies/#{nw}/#{ss}/ns_convert_table"
      get "/topologies/#{nw}/#{ss}/topology/layer3/nodes", { node_type: 'segment' }
      expect(last_response.status).to eq 200
      expect(json_body['nodes'].length).to eq 8
    end

    it 'GET /topology/:layer/nodes returns 404 without ns_convert_table' do
      get "/topologies/#{nw}/#{ss}/topology/layer3/nodes"
      expect(last_response.status).to eq 404
    end

    it 'GET /topology/upper_layer3 excludes layer1/layer2' do
      get "/topologies/#{nw}/#{ss}/topology/upper_layer3"
      expect(last_response.status).to eq 200
      ids = json_body['ietf-network:networks']['network'].map { |n| n['network-id'] }
      expect(ids).to include('layer3')
      expect(ids).not_to include('layer1', 'layer2')
    end

    # NOTE: /verify must be mounted before /:layer (otherwise shadowed by /:layer: 404)
    it 'GET /topology/verify returns messages per layer' do
      get "/topologies/#{nw}/#{ss}/topology/verify", { severity: 'error' }
      expect(last_response.status).to eq 200
      expect(json_body.keys).to include('layer1', 'layer2', 'layer3')
    end

    it 'GET /topology/:layer/verify returns messages of a layer' do
      get "/topologies/#{nw}/#{ss}/topology/layer3/verify", { severity: 'warn' }
      expect(last_response.status).to eq 200
      expect(json_body).to be_an(Array)
    end
  end

  describe 'snapshot / network listing and deletion' do
    before do
      register_topology(nw, 'original_asis', FixtureHelper.fw_topology)
      register_topology(nw, 'emulated_asis', FixtureHelper.fw_topology)
    end

    it 'lists snapshots (with prefix filter)' do
      get "/topologies/#{nw}/snapshots"
      expect(json_body).to match_array %w[original_asis emulated_asis]
      get "/topologies/#{nw}/snapshots", { prefix: 'orig' }
      expect(json_body).to eq ['original_asis']
    end

    it 'DELETE /topologies/:nw/:ss removes the snapshot directory (with ns_convert_table)' do
      post_json "/topologies/#{nw}/original_asis/ns_convert_table"
      dir = File.join(ApiHelper::TOPOLOGIES_DIR, nw, 'original_asis')
      expect(Dir.children(dir)).to match_array %w[topology.json ns_convert_table.json]

      delete "/topologies/#{nw}/original_asis"
      expect(last_response.status).to eq 204
      expect(File.exist?(dir)).to be false
      expect(File.exist?(File.join(ApiHelper::TOPOLOGIES_DIR, nw, 'emulated_asis'))).to be true
    end

    it 'DELETE /topologies/:nw/:ss succeeds even if the snapshot does not exist' do
      delete "/topologies/#{nw}/unknown"
      expect(last_response.status).to eq 204
    end

    it 'DELETE /topologies/:nw removes the network directory' do
      delete "/topologies/#{nw}"
      expect(File.exist?(File.join(ApiHelper::TOPOLOGIES_DIR, nw))).to be false
    end
  end

  describe 'index' do
    it 'saves and fetches netoviz index' do
      index = [{ 'label' => 'x', 'file' => 'x.json' }]
      post_json '/topologies/index', { index_data: index }
      expect(last_response.status).to eq 201
      get '/topologies/index'
      expect(json_body).to eq index
    end

    it 'returns 404 if no index' do
      get '/topologies/index'
      expect(last_response.status).to eq 404
    end
  end
end
