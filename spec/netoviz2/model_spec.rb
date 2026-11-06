# frozen_string_literal: true

RSpec.describe NetomoxExp::Netoviz2::Model do
  include Netoviz2Helper

  let(:model) { build_model(tiny_topology) }
  let(:ids) { NetomoxExp::Netoviz2::ObjectId }

  def warnings_of(code, target = model)
    target.warnings.to_a.select { |w| w[:code] == code }
  end

  describe 'layers' do
    it 'keeps the order of the topology data' do
      expect(model.layers.map(&:id)).to eq %w[layer1 layer2 layer3 bgp_proc]
    end

    it 'has nodes, tps and links of each layer' do
      layer1 = model.layer('layer1')
      expect(layer1.nodes.map(&:id)).to eq %w[layer1/sw%2F1 layer1/sw2]
      expect(layer1.nodes.first.tps.map(&:id)).to eq %w[layer1/sw%2F1/ge-0%2F0%2F1 layer1/sw%2F1/ge-0%2F0%2F2]
      expect(layer1.links.size).to eq 2
    end

    it 'resolves link endpoints to tp ids' do
      link = model.layer('layer1').links.first
      expect(link.src_id).to eq 'layer1/sw%2F1/ge-0%2F0%2F1'
      expect(link.dst_id).to eq 'layer1/sw2/p1'
    end
  end

  describe 'entry' do
    it 'finds objects by id' do
      expect(model.entry('layer1/sw2/p1').type).to eq :tp
      expect(model.entry('layer1/sw%2F1').type).to eq :node
      expect(model.entry('layer3')&.type).to eq :layer
      expect(model.entry('layer1/unknown')).to be_nil
    end

    it 'does not confuse a node with slash and a tp (ids are unambiguous)' do
      expect(model.entry('layer1/sw%2F1/ge-0%2F0%2F1').layer_id).to eq 'layer1'
      expect(model.entry('layer1/sw/1/ge-0/0/1')).to be_nil
    end
  end

  describe 'flags' do
    it 'returns flags of networks-attributes' do
      expect(model.flags).to eq ['blueprint=sample1']
    end

    it 'returns an empty array without networks-attributes' do
      data = tiny_topology
      data['ietf-network:networks'].delete('mddo-topology:networks-attributes')
      expect(build_model(data).flags).to eq []
    end
  end

  describe 'supports' do
    it 'resolves node and tp supports' do
      edges = model.supports.map { |e| [e.kind, e.from, e.to] }
      expect(edges).to include(
        ['node', 'layer2/sw%2F1', 'layer1/sw%2F1'],
        ['tp', 'layer2/sw%2F1/ge-0%2F0%2F1', 'layer1/sw%2F1/ge-0%2F0%2F1'],
        ['node', 'layer3/r1', 'layer2/sw%2F1'],
        ['tp', 'layer3/r1/ge-0%2F0%2F1.0', 'layer2/sw%2F1/ge-0%2F0%2F1']
      )
    end

    it 'excludes supports whose target is not found and warns' do
      expect(model.supports.map(&:from)).not_to include('layer3/r2')
      warnings = warnings_of('dangling_support')
      expect(warnings.size).to eq 1
      expect(warnings.first).to include(severity: 'warn', kind: 'node', from: 'layer3/r2', ref: 'layer2/not-found')
    end

    it 'supports link supports with the same mechanism' do
      data = tiny_topology
      link = data['ietf-network:networks']['network'][0]['ietf-network-topology:link'][0]
      link2 = { 'link-id' => 'a,b,c,d', 'source' => { 'source-node' => 'sw2', 'source-tp' => 'p1' },
                'destination' => { 'dest-node' => 'sw/1', 'dest-tp' => 'ge-0/0/1' },
                'supporting-link' => [{ 'network-ref' => 'layer1', 'link-ref' => link['link-id'] }] }
      data['ietf-network:networks']['network'][1]['ietf-network-topology:link'] << link2
      edges = build_model(data).supports.select { |e| e.kind == 'link' }
      expect(edges.map { |e| [e.from, e.to] })
        .to eq [['layer2/~link/a%2Cb%2Cc%2Cd', ids.link('layer1', link['link-id'])]]
    end
  end

  describe 'layer_graph' do
    it 'merges declared supports and actual references' do
      expect(model.layer_graph.supports).to eq(
        'layer1' => [], 'layer2' => ['layer1'], 'layer3' => ['layer2'], 'bgp_proc' => []
      )
    end

    it 'ranks layers from the lowest' do
      expect(model.layer_graph.ranks).to eq('layer1' => 0, 'layer2' => 1, 'layer3' => 2, 'bgp_proc' => 0)
    end

    it 'warns (info) about declared supports whose layer does not exist' do
      warnings = warnings_of('dangling_layer_support')
      expect(warnings.size).to eq 1
      expect(warnings.first).to include(severity: 'info', layer: 'bgp_proc', ref: 'layer9')
    end

    it 'reports only the layers in the cycle' do
      data = tiny_topology
      data['ietf-network:networks']['network'][0]['supporting-network'] = [{ 'network-ref' => 'layer2' }]
      cyclic = build_model(data)
      layers = warnings_of('layer_support_cycle', cyclic).first[:layers]
      expect(layers.first).to eq layers.last
      expect(layers).not_to include('layer3')
    end

    it 'detects cycles between layers' do
      data = tiny_topology
      data['ietf-network:networks']['network'][0]['supporting-network'] = [{ 'network-ref' => 'layer2' }]
      cyclic = build_model(data)
      expect(cyclic.layer_graph.ranks).to include('layer1' => nil, 'layer2' => nil, 'layer3' => nil)
      expect(cyclic.warnings.to_a.map { |w| w[:code] }).to include('layer_support_cycle')
    end
  end

  describe 'dangling link endpoint' do
    it 'sets nil and warns' do
      data = tiny_topology
      data['ietf-network:networks']['network'][0]['ietf-network-topology:link'][0]['destination']['dest-tp'] = 'xx'
      broken = build_model(data)
      expect(broken.layer('layer1').links.first.dst_id).to be_nil
      expect(warnings_of('dangling_link_endpoint', broken).size).to eq 1
    end
  end

  describe 'id collision' do
    it 'does not collide a node and a link which have the same name' do
      data = tiny_topology
      layer1 = data['ietf-network:networks']['network'][0]
      layer1['node'] << { 'node-id' => 'sw2,p1,sw/1,ge-0/0/1' } # same string as the link-id of the 2nd link
      collided = build_model(data)
      expect(warnings_of('duplicate_id', collided)).to eq []
      expect(collided.layer('layer1').links.size).to eq 2
      expect(collided.layer('layer1').nodes.size).to eq 3
    end
  end

  describe 'names with double underscores' do
    # netomox uses `__` in object paths. Names with `__` must be resolved by name, not by path.
    it 'resolves link endpoints and supports' do
      data = tiny_topology
      layers = data['ietf-network:networks']['network']
      layers[0]['node'][1]['node-id'] = 'sw__2'
      layers[0]['ietf-network-topology:link'].each do |link|
        link['source']['source-node'] = 'sw__2' if link['source']['source-node'] == 'sw2'
        link['destination']['dest-node'] = 'sw__2' if link['destination']['dest-node'] == 'sw2'
      end
      layers[1]['node'][0]['supporting-node'] << { 'network-ref' => 'layer1', 'node-ref' => 'sw__2' }
      underscored = build_model(data)
      expect(underscored.layer('layer1').links.first.dst_id).to eq 'layer1/sw__2/p1'
      expect(underscored.supports.map(&:to)).to include('layer1/sw__2')
    end
  end

  describe 'warnings' do
    it 'keeps at most 100 warnings and counts the total' do
      data = tiny_topology
      nodes = (0...150).map do |i|
        { 'node-id' => "n#{i}", 'supporting-node' => [{ 'network-ref' => 'layer1', 'node-ref' => "x#{i}" }] }
      end
      data['ietf-network:networks']['network'][2]['node'] = nodes
      many = build_model(data)
      expect(many.warnings.to_a.size).to eq 100
      expect(many.warnings.total).to be >= 150
    end
  end

  describe 'duplicate_id' do
    it 'keeps the first node and warns about the later one' do
      data = tiny_topology
      data['ietf-network:networks']['network'][0]['node'] << { 'node-id' => 'sw2' }
      duplicated = build_model(data)
      expect(duplicated.layer('layer1').nodes.size).to eq 2
      expect(warnings_of('duplicate_id', duplicated).size).to eq 1
    end
  end

  describe 'diff?' do
    it 'is false when no object has a diff state (even if _diff_state_ with kept exists)' do
      data = tiny_topology
      state = { 'forward' => 'kept', 'backward' => nil, 'pair' => '' }
      data['ietf-network:networks']['network'][0]['node'][0]['_diff_state_'] = state
      expect(build_model(data).diff?).to be false
    end

    it 'is true when an object is added/deleted/changed' do
      data = tiny_topology
      state = { 'forward' => 'kept', 'backward' => 'changed', 'pair' => '' }
      data['ietf-network:networks']['network'][0]['node'][0]['_diff_state_'] = state
      expect(build_model(data).diff?).to be true
    end
  end

  describe 'real data (mddo-fw)' do
    let(:model) { build_model(FixtureHelper.fw_topology) }

    it 'builds layers without dangling references' do
      expect(model.layers.map(&:id)).to include('layer1', 'layer2', 'layer3', 'ospf_area0')
      expect(model.warnings.to_a).to eq []
      expect(model.diff?).to be false
    end

    it 'derives layer ranks' do
      ranks = model.layer_graph.ranks
      expect(ranks['layer1']).to eq 0
      expect(ranks['layer2']).to eq 1
      expect(ranks['layer3']).to eq 2
      expect(ranks['ospf_area0']).to eq 3
    end
  end
end
