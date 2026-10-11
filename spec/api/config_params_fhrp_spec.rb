# frozen_string_literal: true

require 'app'

# config_params API: `fhrp` of each term-point (used by playbook templates to generate VRRP config)
RSpec.describe 'config_params API with fhrp' do
  include ApiHelper

  let(:nw) { 'mddo-fw' }
  let(:ss) { 'original_asis' }
  let(:base) { "/topologies/#{nw}/#{ss}" }
  let(:fhrp) do
    { 'protocol' => 'vrrp', 'group-id' => 1, 'virtual-address' => ['192.168.100.1'], 'priority' => 150,
      'preempt' => true, 'source-address' => '192.168.100.2/24', 'active' => true }
  end

  def l3_node(topology, node_name)
    l3_nw = topology['ietf-network:networks']['network'].find { |n| n['network-id'] == 'layer3' }
    l3_nw['node'].find { |n| n['node-id'] == node_name }
  end

  # add fhrp to the first term-point (having ip-address) of the node
  def add_fhrp(topology, node_name)
    tps = l3_node(topology, node_name)['ietf-network-topology:termination-point']
    attrs = tps.filter_map { |tp| tp['mddo-topology:l3-termination-point-attributes'] }
    attrs.find { |attr| attr['ip-address']&.any? }['fhrp'] = [fhrp]
  end

  def if_list_of(node_name)
    get "#{base}/topology/layer3/config_params"
    expect(last_response.status).to eq 200
    json_body.find { |n| n['name'] == node_name }['if_list']
  end

  before do
    prepare_dirs
    @topology = FixtureHelper.fw_topology
    add_fhrp(@topology, 'site-a-br-1')
    register_topology(nw, ss, @topology)
    post_json "#{base}/ns_convert_table"
  end

  it 'gives fhrp of the term-point (same keys as topology.json)' do
    if_list = if_list_of('site-a-br-1')
    with_fhrp = if_list.select { |i| i['fhrp'].any? }
    expect(with_fhrp.length).to eq 1
    expect(with_fhrp.first['fhrp']).to eq [fhrp]
  end

  it 'gives an empty fhrp for term-points without fhrp' do
    expect(if_list_of('site-a-br-2').map { |i| i['fhrp'] }).to all(eq [])
  end
end
