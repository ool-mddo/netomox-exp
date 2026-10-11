# frozen_string_literal: true

require 'tmpdir'
require 'lib/netomox_exp'
require 'lib/topology_builder/csv_mapper/fhrp_props_table'

RSpec.describe NetomoxExp::TopologyBuilder::CSVMapper::FhrpPropertiesTable do
  let(:query_dir) { FixtureHelper.path('queries', 'mddo-fw-fhrp', 'original_asis') }
  let(:header) { ',Interface,Group_Id,Virtual_Addresses,Source_Address,Priority,Preempt,Active' }
  let(:hsrp_row) { "0,r1[GigabitEthernet0/1],10,\"['10.0.0.254']\",10.0.0.1/24,110,False,True" }

  # make a query directory that contains only specified csv files
  def with_query_dir(files)
    Dir.mktmpdir('fhrp-spec') do |dir|
      files.each { |name, content| File.write(File.join(dir, name), content) }
      yield dir
    end
  end

  describe 'records of vrrp_props.csv' do
    let(:table) { described_class.new(query_dir) }

    it 'reads all rows (hsrp_props.csv has only header)' do
      expect(table.records.length).to eq 12
      expect(table.records.map(&:protocol).uniq).to eq %w[vrrp]
    end

    it 'converts columns to node, interface and typed values' do
      rec = table.find_all_records_by_node_intf('site-b-cr-1', 'ge-0/0/2.0').first
      expect(rec).to have_attributes(
        protocol: 'vrrp', node: 'site-b-cr-1', interface: 'ge-0/0/2.0', group_id: 1,
        virtual_addresses: %w[192.168.101.1], source_address: '192.168.101.2/24',
        priority: 150, preempt: true, active: true
      )
    end

    it 'differentiates the priority of HA pair' do
      priorities = %w[site-b-cr-1 site-b-cr-2].map do |node|
        table.find_all_records_by_node_intf(node, 'ge-0/0/2.0').first.priority
      end
      expect(priorities).to eq [150, 100]
    end
  end

  describe '#find_all_records_by_node_intf' do
    let(:table) { described_class.new(query_dir) }

    it 'returns [] if the interface does not have fhrp' do
      expect(table.find_all_records_by_node_intf('site-b-cr-1', 'ge-0/0/0.0')).to eq []
      expect(table.find_all_records_by_node_intf('no-such-node', 'ge-0/0/2.0')).to eq []
    end

    it 'returns all groups of the interface, sorted by protocol and group id' do
      vrrp = "0,r1[ge-0/0/0.0],2,\"['10.0.0.253']\",10.0.0.1/24,100,True,True\n" \
             "1,r1[ge-0/0/0.0],1,\"['10.0.0.254']\",10.0.0.1/24,100,True,True"
      files = { 'vrrp_props.csv' => "#{header}\n#{vrrp}\n", 'hsrp_props.csv' => "#{header}\n" }
      with_query_dir(files) do |dir|
        recs = described_class.new(dir).find_all_records_by_node_intf('r1', 'ge-0/0/0.0')
        expect(recs.map(&:group_id)).to eq [1, 2]
      end
    end
  end

  describe 'both of vrrp and hsrp' do
    it 'concatenates records of vrrp_props.csv and hsrp_props.csv with protocol' do
      vrrp = "0,r1[GigabitEthernet0/1],1,\"['10.0.0.253']\",10.0.0.1/24,100,True,True"
      files = { 'vrrp_props.csv' => "#{header}\n#{vrrp}\n", 'hsrp_props.csv' => "#{header}\n#{hsrp_row}\n" }
      with_query_dir(files) do |dir|
        recs = described_class.new(dir).find_all_records_by_node_intf('r1', 'GigabitEthernet0/1')
        expect(recs.map { |r| [r.protocol, r.group_id] }).to eq [['hsrp', 10], ['vrrp', 1]]
        expect(recs.first).to have_attributes(preempt: false, active: true, priority: 110)
      end
    end
  end

  describe 'missing csv files' do
    it 'is treated as empty table (queries of old version)' do
      with_query_dir({}) do |dir|
        expect(described_class.new(dir).records).to eq []
      end
    end

    it 'reads only existing one' do
      with_query_dir({ 'hsrp_props.csv' => "#{header}\n#{hsrp_row}\n" }) do |dir|
        expect(described_class.new(dir).records.map(&:protocol)).to eq %w[hsrp]
      end
    end
  end
end
