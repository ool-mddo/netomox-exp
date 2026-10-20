# frozen_string_literal: true

require 'lib/convert_topology/containerlab_converter'

RSpec.describe NetomoxExp::ConvertTopology::ContainerLabConverter do
  # NOTE: topology: emulated (L3 model names), table: made from the original topology
  let(:emulated) { JSON.parse(File.read(FixtureHelper.path('topologies', 'mddo-fw', 'emulated_asis.topology.json'))) }
  let(:ns_converter) { ConverterHelper.ns_converter_for(FixtureHelper.fw_topology) }
  let(:params) { FixtureHelper.refocus_params }
  let(:options) do
    { image: 'crpd:test', clab_node_params: params['containerlab_nodes'],
      usecase_l3preallocs: params['l3_preallocated_resources'] }
  end
  let(:converter) { described_class.new(emulated, 'layer3', ns_converter, options) }
  let(:clab) { converter.convert }
  let(:nodes) { clab['topology']['nodes'] }
  let(:links) { clab['topology']['links'] }
  let(:endpoints) { links.map { |l| l['endpoints'] } }

  it 'uses env_name option or "emulated" as the name' do
    expect(clab['name']).to eq 'emulated'
    expect(described_class.new(emulated, 'layer3', ns_converter, options.merge(env_name: 'x')).convert['name'])
      .to eq 'x'
  end

  it 'raises error for unknown network / non-layer3 network' do
    expect { described_class.new(emulated, 'no-such', ns_converter) }.to raise_error(StandardError, /not found/)
    expect do
      described_class.new(emulated, 'ospf_area0', ns_converter).convert
    end.to raise_error(StandardError, /not layer3/)
  end

  describe 'nodes' do
    it 'makes cRPD node (default) with startup-config' do
      expect(nodes['site-a-br-1']).to eq({ 'kind' => 'juniper_crpd', 'image' => 'crpd:test',
                                           'startup-config' => 'site-a-br-1.conf' })
    end

    it 'makes ovs-bridge for segment nodes' do
      expect(nodes['br1']).to eq({ 'kind' => 'ovs-bridge' })
    end

    it 'prefers containerlab_nodes definition for FW nodes (and gives no startup-config)' do
      fw = nodes['site-a-fw-1']
      expect(fw).to include('kind' => 'linux', 'image' => 'rtedpro/proxmox:9.2.3')
      expect(fw).to include('ports', 'binds', 'env', 'labels')
      expect(fw).not_to have_key('startup-config')
      expect(fw['labels']).to include('redundant' => 'act')
      expect(nodes['site-a-fw-2']['labels']).to include('redundant' => 'sby')
    end

    it 'falls back to cRPD for FW nodes if containerlab_nodes is not given' do
      c = described_class.new(emulated, 'layer3', ns_converter, { image: 'crpd:test' }).convert
      expect(c['topology']['nodes']['site-a-fw-1']['kind']).to eq 'juniper_crpd'
    end

    it 'adds bind_license/license option to cRPD nodes' do
      c = described_class.new(emulated, 'layer3', ns_converter,
                              { image: 'crpd:test', bind_license: 'l.key:/tmp/l.key', license: '/tmp/l.key' }).convert
      expect(c['topology']['nodes']['site-a-br-1']).to include('binds' => ['l.key:/tmp/l.key'],
                                                               'license' => '/tmp/l.key')
    end
  end

  describe 'links' do
    it 'has one link per bidirectional pair (+ FW pair links)' do
      l3_links = ConverterHelper.links_of(emulated, 'layer3')
      expect(links.length).to eq((l3_links.length / 2) + 4) # 2 FW HA pairs x (eth2, eth3)
    end

    it 'uses l1_principal names for endpoints' do
      expect(endpoints).to include(%w[br0:br0p0 site-a-br-1:eth1])
      expect(endpoints).to include(%w[br1:br1p1 site-a-fw-1:eth4])
    end

    it 'adds direct links (eth2, eth3) between FW HA pair members' do
      %w[site-a site-b].each do |site|
        %w[eth2 eth3].each do |eth|
          expect(endpoints).to include(["#{site}-fw-1:#{eth}", "#{site}-fw-2:#{eth}"])
        end
      end
      expect(endpoints.count { |ep| ep.all? { |e| e.match?(/-fw-\d:eth[23]\z/) } }).to eq 4
    end

    it 'does not add pair links without firewall pair attributes' do
      data = FixtureHelper.deep_dup(emulated)
      l3 = data['ietf-network:networks']['network'].find { |nw| nw['network-id'] == 'layer3' }
      l3['node'].each do |n|
        n.delete('flag')
        n['mddo-topology:l3-node-attributes']&.delete('firewall')
      end
      c = described_class.new(data, 'layer3', ns_converter, options).convert
      pair_links = c['topology']['links'].select do |l|
        l['endpoints'].all? { |e| e.match?(/-fw-\d:eth[23]\z/) }
      end
      expect(pair_links).to be_empty
    end

    it 'does not add pair links if the pair partner node is not found' do
      data = FixtureHelper.deep_dup(emulated)
      l3 = data['ietf-network:networks']['network'].find { |nw| nw['network-id'] == 'layer3' }
      l3['node'].reject! { |n| n['node-id'] == 'site-a-fw-2' }
      c = described_class.new(data, 'layer3', ns_converter, options).convert
      pair_eps = c['topology']['links'].map { |l| l['endpoints'] }.select do |ep|
        ep.all? { |e| e.match?(/-fw-\d:eth[23]\z/) }
      end
      expect(pair_eps.flatten.grep(/site-a/)).to be_empty
      expect(pair_eps).to include(%w[site-b-fw-1:eth2 site-b-fw-2:eth2])
    end

    it 'references only defined nodes' do
      endpoints.flatten.map { |e| e.split(':').first }.uniq.each do |name|
        expect(nodes).to have_key(name)
      end
    end
  end
end
