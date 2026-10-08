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
