# frozen_string_literal: true

require 'lib/convert_namespace/namespace_converter'

RSpec.describe NetomoxExp::ConvertNamespace::NamespaceConverter do
  let(:original) { FixtureHelper.fw_topology }
  let(:converter) { ConverterHelper.ns_converter_for(original) }
  let(:converted) { converter.convert }

  def tp_ids(topology, network, node_id)
    ConverterHelper.nodes_of(topology, network)
                   .find { |n| n['node-id'] == node_id }['ietf-network-topology:termination-point']
                   .map { |tp| tp['tp-id'] }
  end

  # @return [Hash{String => Array<String>}] "network-id/node-id" => top-level flags
  def flagged_nodes(topology)
    topology['ietf-network:networks']['network'].each_with_object({}) do |nw, h|
      (nw['node'] || []).each { |n| h["#{nw['network-id']}/#{n['node-id']}"] = n['flag'] if n['flag'] }
    end
  end

  it 'reproduces the reviewed emulated topology (original_asis -> emulated_asis)' do
    # the fixture 'emulated_asis' is a snapshot of the demo output
    emulated = JSON.parse(File.read(FixtureHelper.path('topologies', 'mddo-fw', 'emulated_asis.topology.json')))
    expect(converted).to eq emulated
  end

  it 'sets the facing router/firewall interface to description of a point-to-point link (skips the segment)' do
    br1 = ConverterHelper.nodes_of(converted, 'layer3').find { |n| n['node-id'] == 'site-a-br-1' }
    descrs = br1['ietf-network-topology:termination-point'].map do |tp|
      tp.dig('mddo-topology:l3-termination-point-attributes', 'description')
    end
    expect(descrs).to eq %w[to_site-a-br-2_eth1 to_site-a-fw-1_ge-0/0/1 to_site-b-br-1_eth1 to_site-c-br-1_ge-0/0/0]
  end

  it 'copies the link-determined description to the same-name term-point of the firewall cluster pair' do
    descrs = lambda do |node_id|
      node = ConverterHelper.nodes_of(converted, 'layer3').find { |n| n['node-id'] == node_id }
      node['ietf-network-topology:termination-point'].to_h do |tp|
        [tp['tp-id'], tp.dig('mddo-topology:l3-termination-point-attributes', 'description')]
      end
    end
    %w[site-a site-b].each do |site|
      expect(descrs.call("#{site}-fw-1")['ge-0/0/1.0']).to eq descrs.call("#{site}-fw-2")['ge-0/0/1.0']
      expect(descrs.call("#{site}-fw-1")['ge-7/0/1.0']).to eq descrs.call("#{site}-fw-2")['ge-7/0/1.0']
      # facing node/tp beyond the point-to-point segment (not the segment)
      expect(descrs.call("#{site}-fw-1")['ge-0/0/1.0']).to match(/\Ato_#{site}-br-1_eth\d+\z/)
    end
  end

  describe 'description of layer3 term-points in special cases' do
    let(:l3_node_attr) { 'mddo-topology:l3-node-attributes' }
    let(:l3_tp_attr) { 'mddo-topology:l3-termination-point-attributes' }
    let(:tp_key) { 'ietf-network-topology:termination-point' }

    def description_of(topology, node_id, tp_id)
      node = ConverterHelper.nodes_of(topology, 'layer3').find { |n| n['node-id'] == node_id }
      node[tp_key].find { |tp| tp['tp-id'] == tp_id }.dig(l3_tp_attr, 'description')
    end

    def layer3_of(topology)
      topology['ietf-network:networks']['network'].find { |nw| nw['network-id'] == 'layer3' }
    end

    def bidirectional_links(node_a, tp_a, node_b, tp_b)
      [[node_a, tp_a, node_b, tp_b], [node_b, tp_b, node_a, tp_a]].map do |sn, st, dn, dt|
        { 'link-id' => "#{sn},#{st},#{dn},#{dt}",
          'source' => { 'source-node' => sn, 'source-tp' => st },
          'destination' => { 'dest-node' => dn, 'dest-tp' => dt } }
      end
    end

    context 'with a multi-access segment (3 endpoints)' do
      # connect an extra term-point of site-a-br-2 to Seg_172.16.1.0/30 (site-a-br-1 <-> site-a-fw-1)
      let(:modified) do
        topology = FixtureHelper.deep_dup(FixtureHelper.fw_topology)
        nw = layer3_of(topology)
        extra_tp = { 'tp-id' => 'ge-0/0/9.0', l3_tp_attr => { 'ip-address' => ['172.16.1.9/30'], 'flag' => [] } }
        nw['node'].find { |n| n['node-id'] == 'site-a-br-2' }[tp_key] << extra_tp
        seg = nw['node'].find { |n| n['node-id'] == 'Seg_172.16.1.0/30' }
        seg[tp_key] << { 'tp-id' => 'site-a-br-2_ge-0/0/9.0', l3_tp_attr => {} }
        nw['ietf-network-topology:link'] +=
          bidirectional_links('Seg_172.16.1.0/30', 'site-a-br-2_ge-0/0/9.0', 'site-a-br-2', 'ge-0/0/9.0')
        topology
      end
      let(:multi_converted) { ConverterHelper.ns_converter_for(modified).convert }

      it 'sets the segment itself (not a facing router) to the description of the endpoints' do
        descr = description_of(multi_converted, 'site-a-fw-1', 'ge-0/0/1.0')
        expect(descr).to start_with('to_Seg-')
      end

      it 'keeps description of the segment term-point to the node' do
        expect(description_of(multi_converted, 'Seg_172.16.1.0/30', 'site-a-fw-1_ge-0/0/1.0'))
          .to eq 'to_site-a-fw-1_ge-0/0/1'
      end
    end

    context 'when the firewall has no cluster pair information' do
      let(:standalone) do
        topology = FixtureHelper.deep_dup(FixtureHelper.fw_topology)
        layer3_of(topology)['node'].each { |n| n.dig(l3_node_attr, 'firewall')&.delete('pair') }
        topology
      end
      let(:standalone_converted) { ConverterHelper.ns_converter_for(standalone).convert }

      it 'does not copy description between the same-name term-points' do
        expect(description_of(standalone_converted, 'site-a-fw-1', 'ge-0/0/1.0')).to start_with('to_site-a-br-1_')
        # unlinked ge-7/0/1.0 keeps the (original) description
        expect(description_of(standalone_converted, 'site-a-fw-1', 'ge-7/0/1.0'))
          .to eq description_of(FixtureHelper.fw_topology, 'site-a-fw-1', 'ge-7/0/1.0')
      end
    end

    it 'does not touch the same-name term-points of the cluster pair when both have no link' do
      %w[ge-0/0/2.0 ge-7/0/2.0].each do |tp_id|
        %w[site-a-fw-1 site-a-fw-2].each do |node_id|
          expect(description_of(converted, node_id, tp_id)).to eq description_of(original, node_id, tp_id)
        end
      end
    end
  end

  it 'does not convert layer1/layer2 networks (only layer3 and upper)' do
    ids = converted['ietf-network:networks']['network'].map { |n| n['network-id'] }
    expect(ids).to include('layer3', 'ospf_area0')
    expect(ids).not_to include('layer1', 'layer2')
  end

  it 'renames cRPD term-points to ethN.0' do
    expect(tp_ids(converted, 'layer3', 'site-a-br-1')).to eq %w[eth1.0 eth2.0 eth3.0 eth4.0]
  end

  it 'keeps JunOS interface names of firewall (vSRX) nodes' do
    expect(tp_ids(converted, 'layer3', 'site-a-fw-1')).to match_array %w[ge-0/0/1.0 ge-0/0/2.0 ge-7/0/1.0 ge-7/0/2.0]
  end

  it 'keeps the firewall attribute, the top-level firewall flag and node count' do
    orig_nodes = ConverterHelper.nodes_of(original, 'layer3')
    conv_nodes = ConverterHelper.nodes_of(converted, 'layer3')
    expect(conv_nodes.length).to eq orig_nodes.length
    fw_names = %w[site-a-fw-1 site-a-fw-2 site-b-fw-1 site-b-fw-2]
    expect(conv_nodes.select { |n| n.dig('mddo-topology:l3-node-attributes', 'firewall') }.map { |n| n['node-id'] })
      .to match_array fw_names
    expect(conv_nodes.select { |n| n['flag']&.include?('firewall') }.map { |n| n['node-id'] })
      .to match_array fw_names
  end

  it 'keeps top-level node flags (not only the firewall) before and after the conversion' do
    flags = ->(topology) { flagged_nodes(topology) }
    expect(flags.call(original)).to eq flags.call(converted)
    expect(flags.call(converted)).not_to be_empty
  end

  it 'keeps the flag in the backward conversion (emulated -> original)' do
    back = ConverterHelper.ns_converter_for(converted)
    expect(flagged_nodes(back.convert)).to eq flagged_nodes(converted)
  end

  it 'keeps link count and every link endpoint refers to an existing term-point' do
    orig_links = ConverterHelper.links_of(original, 'layer3')
    conv_links = ConverterHelper.links_of(converted, 'layer3')
    expect(conv_links.length).to eq orig_links.length

    nodes = ConverterHelper.nodes_of(converted, 'layer3')
    conv_links.each do |link|
      [%w[source source-node source-tp], %w[destination dest-node dest-tp]].each do |side, node_key, tp_key|
        ep = link[side]
        node = nodes.find { |n| n['node-id'] == ep[node_key] }
        expect(node).not_to be_nil
        expect(node['ietf-network-topology:termination-point'].map { |tp| tp['tp-id'] }).to include(ep[tp_key])
      end
    end
  end

  it 'keeps links bidirectional (every link has its reverse link)' do
    pairs = ConverterHelper.links_of(converted, 'layer3')
                           .map { |l| [l['source'].values, l['destination'].values] }
    pairs.each { |src, dst| expect(pairs).to include([dst, src]) }
  end

  describe 'round trip (forward table, reload, no topology)' do
    it 'can be reloaded from a saved table and convert the same way' do
      reloaded = described_class.new
      reloaded.reload(JSON.parse(JSON.generate(converter.to_hash)))
      expect(reloaded.to_hash).to eq converter.to_hash
    end
  end
end
