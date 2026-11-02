# frozen_string_literal: true

require 'lib/netoviz2/summary_builder'
require 'lib/netoviz2/layer_builder'
require 'lib/netoviz2/supports_builder'
require 'lib/netoviz2/attributes_builder'

RSpec.describe 'netoviz2 builders' do
  include Netoviz2Helper

  let(:data) { tiny_topology }
  let(:model) { build_model(data) }

  def changed_state
    { 'forward' => 'kept', 'backward' => 'changed', 'pair' => '', 'diff_data' => [{ 'path' => 'description' }] }
  end

  describe NetomoxExp::Netoviz2::SummaryBuilder do
    let(:summary) { described_class.new(model, network: 'nw', snapshot: 'ss', etag: 'tag').build }
    let(:layers) { summary[:layers].to_h { |l| [l[:id], l] } }

    it 'has basic fields' do
      expect(summary).to include(schema_version: '1', network: 'nw', snapshot: 'ss', etag: 'tag',
                                 flags: ['blueprint=sample1'], has_diff: false)
    end

    it 'orders layers by rank then id' do
      expect(summary[:layers].map { |l| l[:id] }).to eq %w[bgp_proc layer1 layer2 layer3]
    end

    it 'has kind, supports, rank and counts of a layer' do
      expect(layers['layer3']).to include(
        name: 'layer3', kind: 'mddo-topology:l3-network', supports: ['layer2'], rank: 2,
        counts: { nodes: 2, tps: 1, links: 0 }
      )
      expect(layers['layer1'][:counts]).to eq({ nodes: 2, tps: 3, links: 2 })
      expect(layers['layer1']).not_to have_key(:kinds)
    end

    it 'has warnings with the total count' do
      expect(summary[:warnings_total]).to eq 2 # dangling_support, dangling_layer_support
      expect(summary[:warnings].map { |w| w[:code] }).to contain_exactly('dangling_support', 'dangling_layer_support')
    end

    it 'has kind nil without network-types and kinds with multiple network-types' do
      data['ietf-network:networks']['network'][0]['network-types'] = {}
      data['ietf-network:networks']['network'][1]['network-types'] = { 'mddo-topology:l2-network' => {}, 'x:y' => {} }
      summary = described_class.new(model, network: 'nw', snapshot: 'ss', etag: 'tag').build
      layers = summary[:layers].to_h { |l| [l[:id], l] }
      expect(layers['layer1']).to include(kind: nil)
      expect(layers['layer2']).to include(kind: 'mddo-topology:l2-network', kinds: %w[mddo-topology:l2-network x:y])
    end

    it 'sets has_diff when an object is changed' do
      data['ietf-network:networks']['network'][2]['node'][0]['_diff_state_'] = changed_state
      expect(described_class.new(model, network: 'nw', snapshot: 'ss', etag: 'tag').build[:has_diff]).to be true
    end
  end

  describe NetomoxExp::Netoviz2::LayerBuilder do
    let(:builder) { described_class.new(model) }

    it 'returns nil for an unknown layer' do
      expect(builder.build('nothing')).to be_nil
    end

    it 'returns nodes, tps and links (structure only)' do
      result = builder.build('layer1')
      expect(result[:layer]).to eq 'layer1'
      expect(result[:nodes].first).to eq({ id: 'layer1/sw%2F1', name: 'sw/1', tp_count: 2 })
      expect(result[:tps].first).to eq({ id: 'layer1/sw%2F1/ge-0%2F0%2F1', node: 'layer1/sw%2F1', name: 'ge-0/0/1' })
      expect(result[:links].first).to include(src: 'layer1/sw%2F1/ge-0%2F0%2F1', dst: 'layer1/sw2/p1',
                                              name: 'sw/1,ge-0/0/1,sw2,p1')
      expect(result.to_s).not_to include('attributes')
    end

    it 'has kind of the node if node-type exists' do
      nodes = builder.build('layer3')[:nodes]
      expect(nodes.first).to include(name: 'r1', kind: 'node')
      expect(nodes.last).not_to have_key(:kind)
    end

    it 'does not have a diff key for kept objects, even if _diff_state_ exists' do
      data['ietf-network:networks']['network'][2]['node'][0]['_diff_state_'] =
        { 'forward' => 'kept', 'backward' => nil, 'pair' => '' }
      expect(builder.build('layer3')[:nodes].first).not_to have_key(:diff)
    end

    it 'has diff label of changed/added objects' do
      data['ietf-network:networks']['network'][2]['node'][0]['_diff_state_'] = changed_state
      data['ietf-network:networks']['network'][2]['node'][1]['_diff_state_'] =
        { 'forward' => 'added', 'backward' => nil, 'pair' => '' }
      nodes = builder.build('layer3')[:nodes]
      expect(nodes.map { |n| n[:diff] }).to eq %w[changed added]
    end

    it 'keeps null for the endpoint which is not found' do
      data['ietf-network:networks']['network'][0]['ietf-network-topology:link'][0]['destination']['dest-tp'] = 'xx'
      expect(builder.build('layer1')[:links].first).to include(src: 'layer1/sw%2F1/ge-0%2F0%2F1', dst: nil)
    end
  end

  describe NetomoxExp::Netoviz2::SupportsBuilder do
    it 'returns supports of all layers' do
      result = described_class.new(model).build[:supports]
      expect(result).to include({ kind: 'node', from: 'layer2/sw%2F1', to: 'layer1/sw%2F1' })
      expect(result.size).to eq 4
    end
  end

  describe NetomoxExp::Netoviz2::AttributesBuilder do
    let(:builder) { described_class.new(model) }

    it 'returns attributes with attribute key as it is' do
      result = builder.build(['layer3/r1', 'layer3/r1/ge-0%2F0%2F1.0'])
      node = result[:objects]['layer3/r1']
      expect(node[:type]).to eq 'node'
      expect(node[:attributes]).to include('mddo-topology:l3-node-attributes' => include('node-type' => 'node'))
      expect(node[:supporting]).to match({ 'supporting-node' => [include('network-ref' => 'layer2')] })
      tp = result[:objects]['layer3/r1/ge-0%2F0%2F1.0']
      expect(tp[:type]).to eq 'tp'
      expect(tp[:attributes]['mddo-topology:l3-termination-point-attributes']).to include('description' => 'to sw')
      expect(tp[:supporting]).to have_key('supporting-termination-point')
    end

    it 'returns empty attributes for an object without attributes' do
      expect(builder.build(['layer1/sw2'])[:objects]['layer1/sw2']).to eq({ type: 'node', attributes: {} })
    end

    it 'returns layer (network) attributes' do
      layer = builder.build(['layer2'])[:objects]['layer2']
      expect(layer[:type]).to eq 'layer'
      expect(layer[:supporting]).to match({ 'supporting-network' => [include('network-ref' => 'layer1')] })
    end

    it 'lists unknown ids in not_found and ignores duplicated ids' do
      result = builder.build(['layer1/sw2', 'layer1/sw2', 'layer1/none'])
      expect(result[:objects].keys).to eq ['layer1/sw2']
      expect(result[:not_found]).to eq ['layer1/none']
    end

    # netomox restores `_diff_state_` of attributes/supports from data in a version after 0.15.0
    # (https://github.com/ool-mddo/netomox : AttributeBase restores diff state). Skipped with older gems.
    it 'keeps diff state in attributes and supports (diff data of attributes)' do
      restorable = Netomox::Topology::DiffState.respond_to?(:from_data)
      skip 'netomox does not restore diff state of attributes' unless restorable

      node = data['ietf-network:networks']['network'][2]['node'][0]
      node['mddo-topology:l3-node-attributes']['_diff_state_'] = changed_state.merge('pair' => 'attribute')
      node['supporting-node'][0]['_diff_state_'] = { 'forward' => 'kept', 'backward' => nil, 'pair' => 'support' }
      object = builder.build(['layer3/r1'])[:objects]['layer3/r1']
      expect(object[:attributes]['mddo-topology:l3-node-attributes']['_diff_state_'])
        .to include(forward: :kept, backward: :changed, pair: 'attribute', diff_data: [{ 'path' => 'description' }])
      expect(object[:supporting]['supporting-node'].first['_diff_state_']).to include(pair: 'support')
    end

    it 'has diff_state only for objects with diff' do
      data['ietf-network:networks']['network'][2]['node'][0]['_diff_state_'] = changed_state
      objects = builder.build(['layer3/r1', 'layer3/r2'])[:objects]
      expect(objects['layer3/r1'][:diff_state])
        .to include(forward: :kept, backward: :changed, diff_data: [{ 'path' => 'description' }])
      expect(objects['layer3/r2']).not_to have_key(:diff_state)
    end
  end
end
