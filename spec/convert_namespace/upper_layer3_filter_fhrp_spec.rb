# frozen_string_literal: true

require 'lib/netomox_exp'
require 'lib/convert_namespace/upper_layer3_filter'
require 'lib/topology_builder/topology_builder'

RSpec.describe NetomoxExp::ConvertNamespace::UpperLayer3Filter, 'with fhrp (VRRP/HSRP)' do
  let(:query_dir) { FixtureHelper.path('queries', 'mddo-fw-fhrp', 'original_asis') }
  let(:original) { NetomoxExp::TopologyBuilder.generate_data(query_dir) }
  let(:filtered) { described_class.new(original).filter }
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

  it 'keeps fhrp of all layer3 term-points' do
    expect(fhrp_by_tp(original).length).to eq 12
    expect(fhrp_by_tp(filtered)).to eq fhrp_by_tp(original)
  end
end
