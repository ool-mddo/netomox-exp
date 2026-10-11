# frozen_string_literal: true

require 'ipaddress'
require 'lib/netomox_exp'
require 'lib/topology_builder/topology_builder'
require 'lib/static_verifier/static_verifier'

RSpec.describe NetomoxExp::StaticVerifier, 'with fhrp (VRRP/HSRP)' do
  let(:query_dir) { FixtureHelper.path('queries', 'mddo-fw-fhrp', 'original_asis') }
  let(:topology_data) { NetomoxExp::TopologyBuilder.generate_data(query_dir) }

  def verify_layer3(data)
    topology = Netomox::Topology::Networks.new(data)
    described_class.verifier_by_network_type(topology.find_network('layer3')).new(topology, 'layer3').verify('warn')
  end

  def remove_fhrp(data)
    stripped = FixtureHelper.deep_dup(data)
    stripped['ietf-network:networks']['network'].each do |nw|
      nw['node'].each do |node|
        (node['ietf-network-topology:termination-point'] || []).each do |tp|
          tp['mddo-topology:l3-termination-point-attributes']&.delete('fhrp')
        end
      end
    end
    stripped
  end

  it 'reports the same messages as the topology without fhrp' do
    expect(verify_layer3(topology_data)).to eq verify_layer3(remove_fhrp(topology_data))
  end

  it 'reports no error in layer3' do
    expect(verify_layer3(topology_data).map { |m| m[:severity] }).not_to include(:error, :fatal)
  end
end
