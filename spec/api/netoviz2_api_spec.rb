# frozen_string_literal: true

require 'app'

RSpec.describe 'netoviz2 API' do
  include ApiHelper
  include Netoviz2Helper

  let(:base) { '/topologies/nw/ss/netoviz2' }

  before do
    prepare_dirs
    NetomoxExp::Netoviz2ApiHelpers::MODEL_CACHE.clear
    register_topology('nw', 'ss', tiny_topology)
  end

  describe 'GET summary' do
    it 'returns the summary with ETag' do
      get "#{base}/summary"
      expect(last_response.status).to eq 200
      expect(json_body).to include('schema_version' => '1', 'network' => 'nw', 'snapshot' => 'ss',
                                   'flags' => ['blueprint=sample1'], 'has_diff' => false)
      expect(json_body['layers'].map { |l| l['id'] }).to eq %w[bgp_proc layer1 layer2 layer3]
      expect(last_response.headers['ETag']).to eq %("#{json_body['etag']}")
    end

    it 'returns 304 without body when If-None-Match matches' do
      get "#{base}/summary"
      etag = last_response.headers['ETag']
      get "#{base}/summary", {}, { 'HTTP_IF_NONE_MATCH' => etag }
      expect(last_response.status).to eq 304
      expect(last_response.body).to eq ''
    end

    it 'returns the data again when the topology is updated' do
      get "#{base}/summary"
      etag = last_response.headers['ETag']
      data = tiny_topology
      data['ietf-network:networks']['network'][0]['node'] << { 'node-id' => 'sw3' }
      register_topology('nw', 'ss', data)
      get "#{base}/summary", {}, { 'HTTP_IF_NONE_MATCH' => etag }
      expect(last_response.status).to eq 200
      expect(json_body['layers'].find { |l| l['id'] == 'layer1' }['counts']['nodes']).to eq 3
    end

    it 'builds the model only once while the topology is not updated' do
      allow(NetomoxExp::Netoviz2::Model).to receive(:new).and_call_original
      get "#{base}/summary"
      get "#{base}/layers/layer1"
      post_json "#{base}/attributes", { ids: ['layer1/sw2'] }
      expect(NetomoxExp::Netoviz2::Model).to have_received(:new).once
    end

    it 'returns 404 for an unknown snapshot' do
      get '/topologies/nw/unknown/netoviz2/summary'
      expect(last_response.status).to eq 404
    end
  end

  describe 'GET layers/:layer' do
    it 'returns the structure of the layer' do
      get "#{base}/layers/layer1"
      expect(last_response.status).to eq 200
      expect(json_body['layer']).to eq 'layer1'
      expect(json_body['nodes'].map { |n| n['name'] }).to eq %w[sw/1 sw2]
      expect(json_body['links'].size).to eq 2
      expect(json_body['etag']).to be_a(String)
    end

    it 'returns 404 for an unknown layer' do
      get "#{base}/layers/nothing"
      expect(last_response.status).to eq 404
    end

    it 'returns 304 when If-None-Match matches' do
      get "#{base}/layers/layer1"
      get "#{base}/layers/layer1", {}, { 'HTTP_IF_NONE_MATCH' => last_response.headers['ETag'] }
      expect(last_response.status).to eq 304
    end
  end

  describe 'GET supports' do
    it 'returns supports of all layers' do
      get "#{base}/supports"
      expect(last_response.status).to eq 200
      expect(json_body['supports']).to include({ 'kind' => 'node', 'from' => 'layer2/sw%2F1', 'to' => 'layer1/sw%2F1' })
    end
  end

  describe 'POST attributes' do
    it 'returns attributes of the specified objects' do
      post_json "#{base}/attributes", { ids: ['layer3/r1', 'layer1/none'] }
      expect(last_response.status).to eq 200
      expect(json_body['objects']['layer3/r1']['attributes']).to include('mddo-topology:l3-node-attributes')
      expect(json_body['not_found']).to eq ['layer1/none']
    end

    it 'does not respond 304 even if If-None-Match matches (the response depends on ids)' do
      get "#{base}/summary"
      etag = last_response.headers['ETag']
      post_json "#{base}/attributes", { ids: ['layer1/sw2'] }
      header 'If-None-Match', etag
      post_json "#{base}/attributes", { ids: ['layer3/r1'] }
      expect(last_response.status).to eq 200
      expect(json_body['objects'].keys).to eq ['layer3/r1']
    end

    it 'returns 422 without ids' do
      post_json "#{base}/attributes", {}
      expect(last_response.status).to eq 422
      post_json "#{base}/attributes", { ids: [] }
      expect(last_response.status).to eq 422
    end

    it 'returns 422 when ids is not an array of strings' do
      post_json "#{base}/attributes", { ids: 'layer1/sw2' }
      expect(last_response.status).to eq 422
      post_json "#{base}/attributes", { ids: [1, 2] }
      expect(last_response.status).to eq 422
    end

    it 'returns 422 with too many ids' do
      post_json "#{base}/attributes", { ids: Array.new(201) { |i| "layer1/n#{i}" } }
      expect(last_response.status).to eq 422
    end
  end

  describe 'etag' do
    it 'includes the schema version' do
      get "#{base}/summary"
      expect(json_body['etag']).to start_with('v1-')
    end
  end

  describe 'error in the builders' do
    it 'returns 500 with error message in json (not an invalid topology)' do
      allow_any_instance_of(NetomoxExp::Netoviz2::SupportsBuilder).to receive(:build).and_raise(NoMethodError, 'boom')
      get "#{base}/supports"
      expect(last_response.status).to eq 500
      expect(json_body['error']).to include('Internal error', 'NoMethodError', 'boom')
    end
  end

  describe 'invalid topology data' do
    it 'returns 500 with error message' do
      register_topology('nw', 'broken', { 'ietf-network:networks' => { 'unexpected' => [] } })
      get '/topologies/nw/broken/netoviz2/summary'
      expect(last_response.status).to eq 500
      expect(last_response.body).to include('Invalid topology data')
    end
  end

  describe 'real data (mddo-fw)' do
    before { register_topology('nw', 'fw', FixtureHelper.fw_topology) }

    it 'returns layers in the order of dependency without warnings' do
      get '/topologies/nw/fw/netoviz2/summary'
      expect(json_body['warnings']).to eq []
      expect(json_body['layers'].map { |l| l['id'] }.first(3)).to eq %w[layer1 layer2 layer3]
    end
  end
end
