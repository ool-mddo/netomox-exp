# frozen_string_literal: true

require 'lib/netomox_exp'
require 'lib/topology_builder/topology_builder'
require 'lib/convert_topology/containerlab_converter'

RSpec.describe NetomoxExp::ConvertTopology::ContainerLabConverter, 'with endpoint nodes' do
  # original topology with endpoints (site-a-host-1: HOST, site-a-svr1: named "*svr1")
  let(:original) do
    query_dir = FixtureHelper.path('queries', 'mddo-fw-endpoint', 'original_asis')
    FixtureHelper.deep_dup(NetomoxExp::TopologyBuilder.generate_data(query_dir))
  end
  let(:ns_converter) { ConverterHelper.ns_converter_for(original) }
  let(:emulated) { ns_converter.convert }
  let(:options) { { image: 'crpd:test' } }
  let(:converter) { described_class.new(emulated, 'layer3', ns_converter, options) }
  let(:nodes) { converter.convert['topology']['nodes'] }

  it 'makes a linux node with the default endpoint image' do
    expect(nodes['site-a-host-1']).to include('kind' => 'linux', 'image' => 'ghcr.io/ool-mddo/ool-iperf:main')
  end

  it 'uses endpoint_image option' do
    c = described_class.new(emulated, 'layer3', ns_converter, options.merge(endpoint_image: 'ep:test'))
    expect(c.convert['topology']['nodes']['site-a-host-1']['image']).to eq 'ep:test'
  end

  it 'sets ip address, mtu and default route by exec commands' do
    expect(nodes['site-a-host-1']['exec']).to eq [
      'ip addr add 192.168.100.10/24 dev eth1',
      'ip link set dev eth1 mtu 1500',
      'ip route del default',
      'ip route add default via 192.168.100.1'
    ]
  end

  it 'sets only ip/mtu commands if the endpoint has no static routes' do
    expect(nodes['site-a-svr1']['exec']).to eq [
      'ip addr add 192.168.101.20/24 dev eth1',
      'ip link set dev eth1 mtu 1500'
    ]
  end

  it 'does not add exec to router / segment nodes' do
    expect(nodes['site-a-br-1']).not_to have_key('exec')
    segments = nodes.reject { |name, _| name.start_with?('site-') }
    expect(segments.values).to all(satisfy { |n| !n.key?('exec') })
  end

  describe 'static route commands' do
    def host_with_routes(routes)
      data = FixtureHelper.deep_dup(emulated)
      ConverterHelper.nodes_of(data, 'layer3').find { |n| n['node-id'] == 'site-a-host-1' }
                     .tap { |host| host['mddo-topology:l3-node-attributes']['static-route'] = routes }
      data
    end

    def exec_with_routes(routes)
      c = described_class.new(host_with_routes(routes), 'layer3', ns_converter, options)
      c.convert['topology']['nodes']['site-a-host-1']['exec']
    end

    it 'adds non-default route as "ip route add"' do
      route = { 'prefix' => '10.0.0.0/8', 'next-hop' => '192.168.100.254', 'interface' => 'dynamic',
                'metric' => 0, 'preference' => 1, 'description' => '' }
      expect(exec_with_routes([route])).to eq [
        'ip addr add 192.168.100.10/24 dev eth1',
        'ip link set dev eth1 mtu 1500',
        'ip route add 10.0.0.0/8 via 192.168.100.254'
      ]
    end

    it 'has no route commands without static routes' do
      expect(exec_with_routes([]).grep(/ip route/)).to be_empty
    end
  end
end
