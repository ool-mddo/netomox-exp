# frozen_string_literal: true

require 'lib/netomox_exp'
require 'lib/topology_builder/topology_builder'

RSpec.describe NetomoxExp::TopologyBuilder, 'with endpoint nodes' do
  # Batfish query results of the mddo-fw network with endpoints:
  #   site-a-host-1 (Configuration_Format=HOST), site-a-svr1 (named "*svrN", Configuration_Format=LINUX)
  let(:query_dir) { FixtureHelper.path('queries', 'mddo-fw-endpoint', 'original_asis') }
  let(:data) { described_class.generate_data(query_dir) }
  let(:layer3) { data['ietf-network:networks']['network'].find { |nw| nw['network-id'] == 'layer3' } }

  def node_type(node_id)
    layer3['node'].find { |n| n['node-id'] == node_id }.dig('mddo-topology:l3-node-attributes', 'node-type')
  end

  it 'detects a host defined in batfish (Configuration_Format=HOST) as an endpoint' do
    expect(node_type('site-a-host-1')).to eq 'endpoint'
  end

  it 'detects a node named "*svrN" as an endpoint (regardless of Configuration_Format)' do
    expect(node_type('site-a-svr1')).to eq 'endpoint'
  end

  it 'keeps router/firewall nodes as normal nodes' do
    expect(node_type('site-a-br-1')).to eq 'node'
    expect(node_type('site-a-fw-1')).to eq 'node'
  end

  it 'keeps the default route of the endpoint as a static route' do
    host = layer3['node'].find { |n| n['node-id'] == 'site-a-host-1' }
    routes = host.dig('mddo-topology:l3-node-attributes', 'static-route')
    expect(routes.map { |r| [r['prefix'], r['next-hop']] }).to eq [%w[0.0.0.0/0 192.168.100.1]]
  end

  describe 'endpoint detection (private)' do
    let(:builder) do
      NetomoxExp::TopologyBuilder::L3DataBuilder.new(target: query_dir, layer2p: nil)
    end

    it 'treats a node not found in node_props as a normal node' do
      expect(builder.send(:endpoint_node?, 'unknown-node', 'unknown-node')).to be false
    end

    it 'is case-insensitive for "svrN" in the L3 node name' do
      expect(builder.send(:endpoint_node?, 'x', 'Site-SVR2')).to be true
    end
  end
end
