# frozen_string_literal: true

require 'lib/netomox_exp'
require 'lib/topology_builder/topology_builder'

RSpec.describe NetomoxExp::TopologyBuilder, 'with ospf parameters of a firewall HA pair' do
  # Batfish query results of the mddo-fw network:
  #   site-a-fw-1/site-b-fw-1 have `metric 10` on ge-7/0/x, but their HA peers (fw-2) do not.
  #   (only fw-2's ge-7/0/x term-points are linked to the segments in the layer3 topology)
  let(:query_dir) { FixtureHelper.path('queries', 'mddo-fw-ospf-ha', 'original_asis') }
  let(:data) { described_class.generate_data(query_dir) }
  let(:attr_key) { 'mddo-topology:ospf-area-termination-point-attributes' }

  # @return [Hash] ospf-area term-point attribute
  def ospf_tp_attr(area_nw, node_id, tp_id)
    network = data['ietf-network:networks']['network'].find { |nw| nw['network-id'] == area_nw }
    node = network['node'].find { |n| n['node-id'] == node_id }
    node['ietf-network-topology:termination-point'].find { |tp| tp['tp-id'] == tp_id }[attr_key]
  end

  it 'uses the metric of the HA peer (fw-1) for the linked fw-2 term-point' do
    %w[ge-7/0/1.0 ge-7/0/2.0].each do |tp_id|
      expect(ospf_tp_attr('ospf_area10', 'site-a-fw-2', tp_id)['metric']).to eq 10
      expect(ospf_tp_attr('ospf_area20', 'site-b-fw-2', tp_id)['metric']).to eq 10
    end
  end

  it 'keeps the configured metric of the HA pair without peer-specific settings' do
    %w[ge-7/0/1.0 ge-7/0/2.0].each do |tp_id|
      expect(ospf_tp_attr('ospf_area30', 'site-c-fw-2', tp_id)['metric']).to eq 1
    end
    expect(ospf_tp_attr('ospf_area10', 'site-a-fw-1', 'ge-0/0/1.0')['metric']).to eq 1
  end

  it 'has default timers (hello/dead) for the HA pair term-points' do
    timer = ospf_tp_attr('ospf_area10', 'site-a-fw-2', 'ge-7/0/1.0')['timer']
    expect(timer).to include('hello-interval' => 10, 'dead-interval' => 40)
  end
end
