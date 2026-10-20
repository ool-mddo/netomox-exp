# frozen_string_literal: true

require 'lib/netomox_exp'
require 'lib/convert_namespace/namespace_converter'
require 'lib/topology_builder/topology_builder'

RSpec.describe NetomoxExp::ConvertNamespace::NamespaceConverter, 'with fhrp (VRRP/HSRP)' do
  let(:query_dir) { FixtureHelper.path('queries', 'mddo-fw-fhrp', 'original_asis') }
  let(:original) { NetomoxExp::TopologyBuilder.generate_data(query_dir) }
  let(:converter) { ConverterHelper.ns_converter_for(original) }
  let(:converted) { converter.convert }
  let(:attr_key) { 'mddo-topology:l3-termination-point-attributes' }

  # @return [Hash{Array<String> => Array<Hash>}] [node-id, tp-id] => fhrp of layer3 term-points which have fhrp
  def fhrp_by_tp(topology)
    ConverterHelper.nodes_of(topology, 'layer3').each_with_object({}) do |node, h|
      (node['ietf-network-topology:termination-point'] || []).each do |tp|
        fhrp = tp.dig(attr_key, 'fhrp')
        h[[node['node-id'], tp['tp-id']]] = fhrp if fhrp
      end
    end
  end

  # @return [Array<String>] node-id and tp-id in the emulated environment (layer3 model)
  def converted_name(node_id, tp_id)
    [converter.node_name.convert(node_id)['l3_model'], converter.tp_name.convert(node_id, tp_id)['l3_model']]
  end

  it 'keeps fhrp of all term-points (with converted node/term-point names)' do
    orig_fhrp = fhrp_by_tp(original)
    expect(orig_fhrp.length).to eq 12

    expected = orig_fhrp.transform_keys { |node_id, tp_id| converted_name(node_id, tp_id) }
    expect(fhrp_by_tp(converted)).to eq expected
  end

  it 'keeps fhrp of cRPD term-point renamed as ethN.0' do
    # site-b-cr-2[ge-0/0/2.0] (vrrp group 1, priority 100) -> eth3.0
    expect(converted_name('site-b-cr-2', 'ge-0/0/2.0')).to eq %w[site-b-cr-2 eth3.0]
    fhrp = fhrp_by_tp(converted)[%w[site-b-cr-2 eth3.0]]
    expect(fhrp).to eq [
      {
        'protocol' => 'vrrp', 'group-id' => 1, 'virtual-address' => %w[192.168.101.1], 'priority' => 100,
        'preempt' => true, 'source-address' => '192.168.101.3/24', 'active' => true
      }
    ]
  end

  it 'does not add fhrp to term-points which do not have it' do
    expect(fhrp_by_tp(converted).length).to eq fhrp_by_tp(original).length
  end

  it 'keeps the other attributes of the term-point' do
    orig_tp = ConverterHelper.nodes_of(original, 'layer3').find { |n| n['node-id'] == 'site-b-cr-2' }
                             .fetch('ietf-network-topology:termination-point').find { |tp| tp['tp-id'] == 'ge-0/0/2.0' }
    conv_tp = ConverterHelper.nodes_of(converted, 'layer3').find { |n| n['node-id'] == 'site-b-cr-2' }
                             .fetch('ietf-network-topology:termination-point').find { |tp| tp['tp-id'] == 'eth3.0' }
    expect(conv_tp[attr_key]['ip-address']).to eq orig_tp[attr_key]['ip-address']
  end
end
