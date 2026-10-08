# frozen_string_literal: true

require 'lib/convert_namespace/namespace_converter'

RSpec.describe NetomoxExp::ConvertNamespace::ConvertTable do
  let(:topology) { FixtureHelper.fw_topology }
  let(:table) do
    described_class.new.tap { |t| t.load_from_topology(topology) }
  end
  let(:tp_table) { table.tp_name_table.to_data }

  # shortcut: l1_principal name of the term-point
  def principal(node, tp_name)
    tp_table.dig(node, tp_name, 'l1_principal')
  end

  describe 'node_name_table' do
    it 'keeps router/firewall node names and maps segments to bridges' do
      names = table.node_name_table.to_data
      expect(names['site-a-br-1']).to eq({ 'l3_model' => 'site-a-br-1', 'l1_agent' => 'site-a-br-1',
                                           'l1_principal' => 'site-a-br-1' })
      expect(names['site-a-fw-1']['l1_principal']).to eq 'site-a-fw-1'
      expect(names['Seg_172.16.1.0/30']).to include('l1_principal' => 'br1')
    end
  end

  describe 'tp_name_table: cRPD node' do
    it 'renumbers interfaces as sequential ethN' do
      expect(tp_table['site-a-br-1']['ge-0/0/2.0']).to eq({ 'l3_model' => 'eth1.0', 'l1_agent' => 'eth1',
                                                            'l1_principal' => 'eth1' })
      expect(tp_table['site-a-br-1']['ge-0/0/3.0']).to eq({ 'l3_model' => 'eth2.0', 'l1_agent' => 'eth2',
                                                            'l1_principal' => 'eth2' })
    end

    it 'has the backward (emulated -> original) entry' do
      expect(tp_table['site-a-br-1']['eth1.0']['l3_model']).to eq 'ge-0/0/2.0'
    end
  end

  describe 'tp_name_table: firewall (vSRX) node' do
    it 'keeps the original JunOS interface names for l3_model and l1_agent (no unit)' do
      expect(tp_table['site-a-fw-1']['ge-0/0/1.0']).to eq({ 'l3_model' => 'ge-0/0/1.0', 'l1_agent' => 'ge-0/0/1',
                                                            'l1_principal' => 'eth4' })
    end

    it 'assigns eth4.. to own data ports in sorted order' do
      expect(principal('site-a-fw-1', 'ge-0/0/1.0')).to eq 'eth4'
      expect(principal('site-a-fw-1', 'ge-0/0/2.0')).to eq 'eth5'
    end

    it 'assigns the HA partner side ports as an independent eth4.. sequence (ghost ports)' do
      expect(principal('site-a-fw-1', 'ge-7/0/1.0')).to eq 'eth4'
      expect(principal('site-a-fw-1', 'ge-7/0/2.0')).to eq 'eth5'
    end

    it 'does the same for the secondary node (own side is ge-7)' do
      expect(principal('site-a-fw-2', 'ge-7/0/1.0')).to eq 'eth4'
      expect(principal('site-a-fw-2', 'ge-0/0/1.0')).to eq 'eth4'
      expect(principal('site-a-fw-2', 'ge-0/0/2.0')).to eq 'eth5'
    end

    it 'adds fabric interface entries (eth3, no unit suffix)' do
      expect(tp_table['site-a-fw-1']['ge-0/0/0']).to eq({ 'l3_model' => 'ge-0/0/0', 'l1_agent' => 'ge-0/0/0',
                                                          'l1_principal' => 'eth3' })
      expect(tp_table['site-a-fw-2']['ge-7/0/0']['l1_principal']).to eq 'eth3'
    end

    context 'with additional ports (sorting / sub-interface / ghost group)' do
      let(:topology) do
        FixtureHelper.deep_dup(FixtureHelper.fw_topology).tap do |data|
          l3 = data['ietf-network:networks']['network'].find { |nw| nw['network-id'] == 'layer3' }
          fw1 = l3['node'].find { |n| n['node-id'] == 'site-a-fw-1' }
          tps = fw1['ietf-network-topology:termination-point']
          template = tps.find { |tp| tp['tp-id'] == 'ge-0/0/1.0' }
          %w[ge-0/0/1.1 ge-0/0/10.0 ge-7/0/10.0].each do |id|
            tps << template.merge('tp-id' => id)
          end
        end
      end

      it 'shares eth number between sub-interfaces of the same physical port' do
        expect(principal('site-a-fw-1', 'ge-0/0/1.1')).to eq principal('site-a-fw-1', 'ge-0/0/1.0')
      end

      it 'sorts ports numerically (ge-0/0/10 after ge-0/0/2)' do
        expect(principal('site-a-fw-1', 'ge-0/0/2.0')).to eq 'eth5'
        expect(principal('site-a-fw-1', 'ge-0/0/10.0')).to eq 'eth6'
      end

      it 'numbers the partner (ge-7) group independently from eth4' do
        expect(principal('site-a-fw-1', 'ge-7/0/1.0')).to eq 'eth4'
        expect(principal('site-a-fw-1', 'ge-7/0/2.0')).to eq 'eth5'
        expect(principal('site-a-fw-1', 'ge-7/0/10.0')).to eq 'eth6'
      end
    end
  end

  describe 'firewall node detection' do
    it 'uses the top-level flag ["firewall"] (not node attributes)' do
      data = FixtureHelper.deep_dup(topology)
      l3 = data['ietf-network:networks']['network'].find { |nw| nw['network-id'] == 'layer3' }
      l3['node'].find { |n| n['node-id'] == 'site-a-fw-1' }.delete('flag')
      t = described_class.new.tap { |ct| ct.load_from_topology(data) }
      # without the flag the node is handled as a cRPD node (ethN.0)
      expect(t.tp_name_table.to_data['site-a-fw-1']['ge-0/0/1.0']['l3_model']).to eq 'eth1.0'
    end
  end

  describe 'convert table made from a converted (emulated) topology' do
    let(:emulated) do
      JSON.parse(File.read(FixtureHelper.path('topologies', 'mddo-fw', 'emulated_asis.topology.json')))
    end
    let(:emulated_table) { described_class.new.tap { |t| t.load_from_topology(emulated) } }

    it 'still detects firewall nodes (the flag is kept in the converted topology)' do
      # as a firewall node: JunOS names are kept (not renumbered as ethN.0)
      expect(emulated_table.tp_name_table.to_data['site-a-fw-1']['ge-0/0/1.0']['l3_model']).to eq 'ge-0/0/1.0'
    end
  end

  describe 'static_route_tp_table / ospf_proc_id_table' do
    it 'has no static route entries for the fixture' do
      expect(table.static_route_tp_table.to_data).to eq({})
    end

    it 'has ospf process id entries for each node' do
      expect(table.ospf_proc_id_table.to_data['site-a-br-1']).to eq({ 'default' => 'default' })
    end
  end

  describe 'serialization' do
    it 'restores the same table by to_hash -> JSON -> reload' do
      restored = described_class.new
      restored.reload(JSON.parse(JSON.generate(table.to_hash)))
      expect(restored.to_hash).to eq table.to_hash
    end

    it 'finds l1 alias with a reloaded table (without topology)' do
      restored = described_class.new
      restored.reload(JSON.parse(JSON.generate(table.to_hash)))
      # argument is the emulated (L3 model) name, result is the emulated-side name set
      expect(restored.tp_name_table.find_l1_alias('site-a-br-1', 'eth1.0')).to include('l1_principal' => 'eth1')
      expect(restored.tp_name_table.find_l1_alias('site-a-fw-1', 'ge-0/0/1.0')).to include('l1_principal' => 'eth4')
    end
  end

  describe 'tp_name_table#key? / #convert' do
    it 'checks node/tp existence' do
      tp = table.tp_name_table
      expect(tp.key?('site-a-br-1')).to be true
      expect(tp.key?('site-a-br-1', 'ge-0/0/2.0')).to be true
      expect(tp.key?('site-a-br-1', 'unknown')).to be false
      expect(tp.key?('unknown')).to be false
    end

    it 'raises error for unknown node/tp' do
      expect { table.tp_name_table.convert('unknown', 'x') }.to raise_error(StandardError, /not in tp-table/)
      expect { table.tp_name_table.convert('site-a-br-1', 'x') }.to raise_error(StandardError, /not in tp-table/)
    end
  end

  describe 'subset golden' do
    it 'matches the reviewed table for representative nodes' do
      actual = {
        'tp_name_table' => tp_table.slice('site-a-br-1', 'site-a-fw-1', 'site-a-fw-2'),
        'node_name_table' => table.node_name_table.to_data.slice('site-a-br-1', 'site-a-fw-1', 'Seg_172.16.1.0/30')
      }
      expect(GoldenHelper.normalize(actual)).to eq GoldenHelper.expected('ns_convert_table_subset.json', actual)
    end
  end
end
