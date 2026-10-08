# frozen_string_literal: true

require 'lib/convert_namespace/upper_layer3_filter'

RSpec.describe NetomoxExp::ConvertNamespace::UpperLayer3Filter do
  let(:original) { FixtureHelper.fw_topology }
  let(:filtered) { described_class.new(original).filter }

  def network_ids(topology)
    topology['ietf-network:networks']['network'].map { |nw| nw['network-id'] }
  end

  it 'keeps layer3 and upper layers only' do
    expect(network_ids(filtered)).to match_array %w[layer3 ospf_area0 ospf_area10 ospf_area20]
  end

  it 'does not rename nodes or term-points' do
    l3 = ConverterHelper.nodes_of(filtered, 'layer3')
    expect(l3.map { |n| n['node-id'] }).to match_array(ConverterHelper.nodes_of(original, 'layer3').map { |n|
      n['node-id']
    })
  end

  it 'keeps the top-level firewall flag' do
    fw_nodes = ConverterHelper.nodes_of(filtered, 'layer3').select { |n| n['flag']&.include?('firewall') }
    expect(fw_nodes.map { |n| n['node-id'] }).to match_array %w[site-a-fw-1 site-a-fw-2 site-b-fw-1 site-b-fw-2]
  end
end
