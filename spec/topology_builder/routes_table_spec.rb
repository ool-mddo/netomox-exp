# frozen_string_literal: true

require 'lib/topology_builder/csv_mapper/routes_table'

RSpec.describe NetomoxExp::TopologyBuilder::CSVMapper::RoutesTableRecord do
  def build(next_hop, **legacy)
    described_class.new({ node: 'n1', vrf: 'default', network: '0.0.0.0/0', next_hop: next_hop,
                          protocol: 'static', metric: 0, admin_distance: 1 }.merge(legacy))
  end

  context 'without legacy Next_Hop_IP/Next_Hop_Interface columns (newer Batfish)' do
    it 'decomposes "interface X ip Y"' do
      route = build('interface eth0 ip 192.168.100.1')
      expect([route.next_hop_ip, route.next_hop_interface]).to eq ['192.168.100.1', 'eth0']
    end

    it 'decomposes "ip Y" (interface is dynamic)' do
      route = build('ip 10.0.0.1')
      expect([route.next_hop_ip, route.next_hop_interface]).to eq %w[10.0.0.1 dynamic]
    end

    it 'decomposes "interface X" (no next-hop ip)' do
      route = build('interface ge-0/0/2.0')
      expect([route.next_hop_ip, route.next_hop_interface]).to eq ['AUTO/NONE(-1l)', 'ge-0/0/2.0']
    end

    it 'decomposes "discard"' do
      route = build('discard')
      expect([route.next_hop_ip, route.next_hop_interface]).to eq %w[AUTO/NONE(-1l) null_interface]
    end

    it 'keeps nil values for a missing Next_Hop' do
      route = build(nil)
      expect([route.next_hop_ip, route.next_hop_interface]).to eq [nil, nil]
    end
  end

  context 'with legacy columns (older Batfish)' do
    it 'prefers the column values' do
      route = build('interface eth0 ip 192.168.100.1', next_hop_ip: '1.1.1.1', next_hop_interface: 'ethX')
      expect([route.next_hop_ip, route.next_hop_interface]).to eq %w[1.1.1.1 ethX]
    end
  end
end
