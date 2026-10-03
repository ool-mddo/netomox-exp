# frozen_string_literal: true

require 'lib/convert_topology/batfish_converter'

RSpec.describe NetomoxExp::ConvertTopology::BatfishConverter do
  let(:emulated) { JSON.parse(File.read(FixtureHelper.path('topologies', 'mddo-fw', 'emulated_asis.topology.json'))) }
  let(:ns_converter) { ConverterHelper.ns_converter_for(FixtureHelper.fw_topology) }
  let(:layer1) { described_class.new(emulated, 'layer3', ns_converter).convert }

  it 'makes edges for every (bidirectional) link' do
    expect(layer1['edges'].length).to eq ConverterHelper.links_of(emulated, 'layer3').length
  end

  it 'uses l1_agent names (interfaceName without unit for FW nodes)' do
    edge = layer1['edges'].find { |e| e['node1']['hostname'] == 'site-a-fw-1' }
    expect(edge['node1']['interfaceName']).to match(%r{\Age-\d/0/\d\z})
  end

  it 'uses emulated l1_agent names for cRPD nodes' do
    names = layer1['edges'].map { |e| e['node1'] }.select { |n| n['hostname'] == 'site-a-br-1' }
    expect(names.map { |n| n['interfaceName'] }).to all(match(/\Aeth\d+\z/))
  end
end
