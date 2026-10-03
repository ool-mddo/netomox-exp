# frozen_string_literal: true

require 'app'

RSpec.describe 'ns_convert_table API and its dependents' do
  include ApiHelper

  let(:nw) { 'mddo-fw' }
  let(:ss) { 'original_asis' }
  let(:table_file) { File.join(ApiHelper::TOPOLOGIES_DIR, nw, ss, 'ns_convert_table.json') }
  let(:base) { "/topologies/#{nw}/#{ss}" }

  before do
    prepare_dirs
    register_topology(nw, ss, FixtureHelper.fw_topology)
  end

  describe 'POST/GET/DELETE ns_convert_table' do
    it 'initializes the table from the snapshot topology (empty body)' do
      post_json "#{base}/ns_convert_table"
      expect(last_response.status).to eq 201
      expect(File.exist?(table_file)).to be true

      get "#{base}/ns_convert_table"
      expect(last_response.status).to eq 200
      expect(json_body.keys).to match_array %w[node_name_table tp_name_table ospf_proc_id_table static_route_tp_table]
      expect(json_body['tp_name_table']['site-a-fw-1']['ge-0/0/1.0']['l1_principal']).to eq 'eth4'
    end

    it 'initializes the table with usecase params' do
      post_json "#{base}/ns_convert_table", { usecase: 'refocus_topology' }
      expect(last_response.status).to eq 201
      expect(File.exist?(table_file)).to be true
    end

    it 'saves given convert_table as it is (manual override)' do
      table = { 'node_name_table' => { 'r1' => { 'l3_model' => 'r1', 'l1_agent' => 'r1', 'l1_principal' => 'r1' } },
                'tp_name_table' => {}, 'ospf_proc_id_table' => {}, 'static_route_tp_table' => {} }
      post_json "#{base}/ns_convert_table", { convert_table: table }
      expect(last_response.status).to eq 201
      get "#{base}/ns_convert_table"
      expect(json_body).to eq table
    end

    it 'returns 404 for GET before initialization' do
      get "#{base}/ns_convert_table"
      expect(last_response.status).to eq 404
    end

    it 'returns 404 for POST (initialization) without topology' do
      post_json "/topologies/#{nw}/no-topology/ns_convert_table"
      expect(last_response.status).to eq 404
    end

    it 'deletes only the table file (topology is kept)' do
      post_json "#{base}/ns_convert_table"
      delete "#{base}/ns_convert_table"
      expect(File.exist?(table_file)).to be false
      expect(File.exist?(File.join(File.dirname(table_file), 'topology.json'))).to be true
    end

    it 'manages tables independently per snapshot' do
      register_topology(nw, 'other', FixtureHelper.fw_topology)
      post_json "#{base}/ns_convert_table"
      get "/topologies/#{nw}/other/ns_convert_table"
      expect(last_response.status).to eq 404
    end
  end

  describe 'POST ns_convert_table/query' do
    before { post_json "#{base}/ns_convert_table" }

    it 'converts host name and interface name' do
      post_json "#{base}/ns_convert_table/query", { host_name: 'site-a-br-1', if_name: 'ge-0/0/2.0' }
      expect(last_response.status).to eq 201
      expect(json_body['origin_host']).to eq 'site-a-br-1'
      expect(json_body['target_if']).to include('l3_model' => 'eth1.0', 'l1_principal' => 'eth1')
    end

    it 'returns 404 for unknown host' do
      post_json "#{base}/ns_convert_table/query", { host_name: 'unknown' }
      expect(last_response.status).to eq 404
    end
  end

  # APIs that need ns_convert_table: 404 before the table initialization, 200 after that
  describe 'dependent APIs' do
    {
      'converted_topology' => ->(base) { "#{base}/converted_topology" },
      'batfish_layer1_topology' => ->(base) { "#{base}/topology/layer3/batfish_layer1_topology" },
      'containerlab_topology' => ->(base) { "#{base}/topology/layer3/containerlab_topology?image=crpd:test" },
      'layer nodes' => ->(base) { "#{base}/topology/layer3/nodes" },
      'layer interfaces' => ->(base) { "#{base}/topology/layer3/interfaces" },
      'config_params' => ->(base) { "#{base}/topology/layer3/config_params" }
    }.each do |name, path_proc|
      it "#{name}: 404 without the table, 200 with it" do
        get path_proc.call(base)
        expect(last_response.status).to eq 404

        post_json "#{base}/ns_convert_table"
        get path_proc.call(base)
        expect(last_response.status).to eq 200
      end
    end

    it 'converted_topology returns the emulated topology' do
      post_json "#{base}/ns_convert_table"
      get "#{base}/converted_topology"
      emulated = JSON.parse(File.read(FixtureHelper.path('topologies', 'mddo-fw', 'emulated_asis.topology.json')))
      expect(json_body).to eq emulated
    end

    it 'config_params gives original/agent names for FW and cRPD nodes' do
      post_json "#{base}/ns_convert_table"
      get "#{base}/topology/layer3/config_params", { node_type: 'node' }
      nodes = json_body.to_h { |n| [n['name'], n] }
      fw_if = nodes['site-a-fw-1']['if_list'].find { |i| i['name'] == 'ge-0/0/1.0' }
      expect(fw_if).to include('agent_name' => 'ge-0/0/1')
      expect(nodes['site-a-br-1']['agent_name']).to eq 'site-a-br-1'
    end
  end

  describe 'containerlab_topology with usecase params' do
    before do
      register_topology(nw, 'emulated_asis', JSON.parse(File.read(FixtureHelper.path('topologies', 'mddo-fw',
                                                                                     'emulated_asis.topology.json'))))
      # NOTE: table of the original snapshot (original -> emulated names) is used for l1 names
      post_json "#{base}/ns_convert_table"
      post_json "/topologies/#{nw}/emulated_asis/ns_convert_table", { convert_table: json_body_table }
    end

    def json_body_table
      get "#{base}/ns_convert_table"
      json_body
    end

    it 'applies containerlab_nodes of the usecase params to FW nodes' do
      get "/topologies/#{nw}/emulated_asis/topology/layer3/containerlab_topology",
          { image: 'crpd:test', usecase: 'refocus_topology' }
      expect(last_response.status).to eq 200
      nodes = json_body['topology']['nodes']
      expect(nodes['site-a-fw-1']).to include('kind' => 'linux', 'image' => 'rtedpro/proxmox:9.2.3')
      expect(nodes['site-a-br-1']).to include('kind' => 'juniper_crpd', 'image' => 'crpd:test')
    end

    it 'treats FW nodes as cRPD without the usecase param' do
      get "/topologies/#{nw}/emulated_asis/topology/layer3/containerlab_topology", { image: 'crpd:test' }
      expect(json_body['topology']['nodes']['site-a-fw-1']['kind']).to eq 'juniper_crpd'
    end

    it 'requires the image param' do
      get "/topologies/#{nw}/emulated_asis/topology/layer3/containerlab_topology"
      expect(last_response.status).to eq 400
    end
  end
end
