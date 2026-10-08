# frozen_string_literal: true

require 'lib/netomox_exp'
require 'lib/topology_builder/topology_builder'

RSpec.describe NetomoxExp::TopologyBuilder do
  # Batfish query results of the mddo-fw (Juniper SRX HA cluster) network
  let(:query_dir) { FixtureHelper.path('queries', 'mddo-fw', 'original_asis') }

  describe '.generate_data' do
    let(:data) { described_class.generate_data(query_dir) }
    let(:networks) { data['ietf-network:networks']['network'] }

    def network(id)
      networks.find { |nw| nw['network-id'] == id }
    end

    def nodes(id)
      network(id)['node']
    end

    def links(id)
      network(id)['ietf-network-topology:link']
    end

    it 'generates all layers (L1, L2, L3, OSPF areas)' do
      expect(networks.map { |nw| nw['network-id'] }).to match_array %w[layer1 layer2 layer3 ospf_area0 ospf_area10
                                                                       ospf_area20]
    end

    it 'sets network types' do
      expect(network('layer1')['network-types'].keys).to eq ['mddo-topology:l1-network']
      expect(network('layer3')['network-types'].keys).to eq ['mddo-topology:l3-network']
      expect(network('ospf_area0')['network-types'].keys).to eq ['mddo-topology:ospf-area-network']
    end

    it 'generates router/firewall nodes in layer3 with segment nodes' do
      names = nodes('layer3').map { |n| n['node-id'] }
      expect(names).to include('site-a-br-1', 'site-a-br-2', 'site-b-br-1', 'site-b-br-2',
                               'site-a-fw-1', 'site-a-fw-2', 'site-b-fw-1', 'site-b-fw-2')
      expect(names.grep(/^Seg_/).length).to eq 8
    end

    it 'has links in both directions for each layer' do
      %w[layer1 layer2 layer3].each do |id|
        keys = links(id).map { |l| [l['source'].values, l['destination'].values] }
        keys.each { |src, dst| expect(keys).to include([dst, src]) }
      end
    end

    it 'has the segment prefix and the term-point ip of a link in the same subnet' do
      seg = nodes('layer3').find { |n| n['node-id'] == 'Seg_172.16.0.0/30' }
      prefix = seg.dig('mddo-topology:l3-node-attributes', 'prefix').first['prefix']
      br1 = nodes('layer3').find { |n| n['node-id'] == 'site-a-br-1' }
      tp = br1['ietf-network-topology:termination-point'].find { |t| t['tp-id'] == 'ge-0/0/2.0' }
      ip = tp.dig('mddo-topology:l3-termination-point-attributes', 'ip-address').first
      expect(IPAddr.new(prefix).include?(IPAddr.new(ip.split('/').first))).to be true
    end

    it 'keeps every layer3 term-point of firewall HA members (own and partner side ports)' do
      fw1 = nodes('layer3').find { |n| n['node-id'] == 'site-a-fw-1' }
      tp_names = fw1['ietf-network-topology:termination-point'].map { |t| t['tp-id'] }
      expect(tp_names).to include('ge-0/0/1.0', 'ge-0/0/2.0', 'ge-7/0/1.0', 'ge-7/0/2.0')
    end

    it 'is deterministic (same input, same output)' do
      expect(described_class.generate_data(query_dir)).to eq data
    end

    it 'raises error if a query file is missing' do
      Dir.mktmpdir do |dir|
        expect { described_class.generate_data(dir) }.to raise_error(StandardError)
      end
    end
  end

  describe 'LO_INTERFACE_REGEXP' do
    {
      'lo0.0' => true, 'lo' => true, 'Loopback0' => true, 'loopback-1' => true, 'lo0.1' => true,
      'ge-0/0/1.0' => false, 'eth1.0' => false, 'xe-0/0/0:0.0' => false
    }.each do |name, expected|
      it "#{expected ? 'matches' : 'does not match'} #{name}" do
        expect(described_class::LO_INTERFACE_REGEXP.match?(name)).to be expected
      end
    end
  end

  describe 'JUNOS_INTERFACE_REGEXP' do
    {
      'xe-0/3/0:0.0' => ['xe-0/3/0:0.0', 'xe-0/3/0:0', '0'],
      'ge-0/10.1112' => ['ge-0/10.1112', 'ge-0/10', '1112'],
      'ge-0/0/1.0' => ['ge-0/0/1.0', 'ge-0/0/1', '0'],
      'lo0.0' => ['lo0.0', 'lo0', '0']
    }.each do |name, expected|
      it "splits #{name} into physical name and unit" do
        expect(described_class::JUNOS_INTERFACE_REGEXP.match(name).to_a).to eq expected
      end
    end

    it 'does not match a name without unit' do
      expect(described_class::JUNOS_INTERFACE_REGEXP.match('ge-0/0/1')).to be_nil
    end
  end
end
