# frozen_string_literal: true

require 'lib/netomox_exp'
require 'lib/topology_builder/topology_builder'

RSpec.describe NetomoxExp::TopologyBuilder, 'with fhrp (VRRP/HSRP)' do
  # Batfish query results of the mddo-fw network (with Juniper cr nodes that own VRRP groups)
  let(:query_dir) { FixtureHelper.path('queries', 'mddo-fw-fhrp', 'original_asis') }
  let(:data) { described_class.generate_data(query_dir) }
  let(:layer3) { data['ietf-network:networks']['network'].find { |nw| nw['network-id'] == 'layer3' } }
  let(:attr_key) { 'mddo-topology:l3-termination-point-attributes' }

  # @return [Array<Array(String, Hash)>] pairs of node-id and term-point data in layer3
  def l3_tps(topology = layer3)
    topology['node'].flat_map do |node|
      (node['ietf-network-topology:termination-point'] || []).map { |tp| [node['node-id'], tp] }
    end
  end

  def l3_tp(node_id, tp_id)
    l3_tps.find { |n, tp| n == node_id && tp['tp-id'] == tp_id }&.last
  end

  it 'adds fhrp to the layer3 term-point which owns a VRRP group' do
    attr = l3_tp('site-b-cr-1', 'ge-0/0/2.0')[attr_key]
    expect(attr['ip-address']).to eq %w[192.168.101.2/24]
    expect(attr['fhrp']).to eq [
      {
        'protocol' => 'vrrp',
        'group-id' => 1,
        'virtual-address' => %w[192.168.101.1],
        'priority' => 150,
        'preempt' => true,
        'source-address' => '192.168.101.2/24',
        'active' => true
      }
    ]
  end

  it 'has different priority and the same virtual address in HA pair' do
    cr1 = l3_tp('site-b-cr-1', 'ge-0/0/3.0')[attr_key]['fhrp'].first
    cr2 = l3_tp('site-b-cr-2', 'ge-0/0/3.0')[attr_key]['fhrp'].first
    expect([cr1['group-id'], cr2['group-id']]).to eq [2, 2]
    expect([cr1['priority'], cr2['priority']]).to eq [150, 100]
    expect(cr1['virtual-address']).to eq cr2['virtual-address']
  end

  it 'adds fhrp only to the term-points of csv records (one for each row)' do
    with_fhrp = l3_tps.select { |_n, tp| tp[attr_key]&.key?('fhrp') }
    expect(with_fhrp.length).to eq 12
    expect(with_fhrp.map(&:first).uniq).to match_array %w[site-a-cr-1 site-a-cr-2 site-b-cr-1 site-b-cr-2
                                                          site-c-cr-1 site-c-cr-2]
  end

  it 'does not add fhrp key to other term-points (routers, firewalls and segments)' do
    others = l3_tps.reject { |n, _tp| n.end_with?('cr-1', 'cr-2') && !n.start_with?('Seg_') }
    expect(others).not_to be_empty
    expect(others.map { |_n, tp| tp[attr_key] || {} }).to all(satisfy { |attr| !attr.key?('fhrp') })
  end

  it 'does not add fhrp key to term-points without vrrp group in cr nodes' do
    cr_tps = l3_tps.select { |n, _tp| n.start_with?('site-b-cr-') }
    without = cr_tps.reject { |_n, tp| %w[ge-0/0/2.0 ge-0/0/3.0].include?(tp['tp-id']) }
    expect(without).not_to be_empty
    expect(without.map { |_n, tp| tp[attr_key] || {} }).to all(satisfy { |attr| !attr.key?('fhrp') })
  end

  it 'generates the same data every time (stable order)' do
    expect(described_class.generate_data(query_dir)).to eq data
  end

  it 'can be parsed by netomox topology classes' do
    topology = Netomox::Topology::Networks.new(data)
    tp = topology.find_network('layer3').find_node_by_name('site-a-cr-1').find_tp_by_name('ge-0/0/3.0')
    fhrp = tp.attribute.fhrp
    expect(fhrp.length).to eq 1
    expect(fhrp.first).to be_a Netomox::Topology::MddoFhrp
    expect(fhrp.first).to have_attributes(protocol: 'vrrp', group_id: 2, priority: 150,
                                          virtual_addresses: %w[192.168.200.1])
  end

  it 'generates data without fhrp from the queries without vrrp_props.csv (old version)' do
    old_data = described_class.generate_data(FixtureHelper.path('queries', 'mddo-fw', 'original_asis'))
    old_l3 = old_data['ietf-network:networks']['network'].find { |nw| nw['network-id'] == 'layer3' }
    attrs = l3_tps(old_l3).map { |_n, tp| tp[attr_key] || {} }
    expect(attrs).to all(satisfy { |attr| !attr.key?('fhrp') })
  end
end
