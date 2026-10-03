# frozen_string_literal: true

require 'ipaddress'
require 'lib/netomox_exp'
require 'lib/static_verifier/static_verifier'

RSpec.describe NetomoxExp::StaticVerifier do
  def verify_all(topology_data, severity = 'warn')
    topology = Netomox::Topology::Networks.new(topology_data)
    topology.networks.to_h do |nw|
      [nw.name, described_class.verifier_by_network_type(nw).new(topology, nw.name).verify(severity)]
    end
  end

  let(:topology_data) { FixtureHelper.fw_topology }

  describe '.verifier_by_network_type' do
    it 'selects a verifier for each layer' do
      topology = Netomox::Topology::Networks.new(topology_data)
      classes = topology.networks.to_h { |nw| [nw.name, described_class.verifier_by_network_type(nw)] }
      expect(classes['layer1']).to eq described_class::Layer1Verifier
      expect(classes['layer2']).to eq described_class::Layer2Verifier
      expect(classes['layer3']).to eq described_class::Layer3Verifier
      expect(classes['ospf_area0']).to eq described_class::OspfAreaVerifier
    end
  end

  describe 'verification of a valid topology' do
    let(:result) { verify_all(topology_data) }

    it 'reports no fatal messages in any layer' do
      result.each_value { |logs| expect(logs.map { |m| m[:severity] }).not_to include(:fatal) }
    end

    it 'reports no error in layer1/layer2/layer3' do
      %w[layer1 layer2 layer3].each do |layer|
        expect(result[layer].map { |m| m[:severity] }).not_to include(:error), layer
      end
    end

    it 'reports unlinked term-points of firewall HA ports as warn (ghost ports)' do
      msgs = result['layer3'].select { |m| m[:target].include?('site-a-fw-1__ge-7/0/1.0') }
      expect(msgs.map { |m| m[:severity] }).to eq [:warn]
    end

    it 'filters messages by severity' do
      errors_only = verify_all(topology_data, 'error')
      expect(errors_only['layer3']).to be_empty
    end
  end

  describe 'verification of a broken topology' do
    it 'reports error for a term-point ip that mismatches its segment prefix' do
      data = FixtureHelper.deep_dup(topology_data)
      l3 = data['ietf-network:networks']['network'].find { |nw| nw['network-id'] == 'layer3' }
      tp = l3['node'].find { |n| n['node-id'] == 'site-a-br-1' }['ietf-network-topology:termination-point']
                     .find { |t| t['tp-id'] == 'ge-0/0/2.0' }
      tp['mddo-topology:l3-termination-point-attributes']['ip-address'] = ['10.9.9.9/30']

      errors = verify_all(data)['layer3'].select { |m| m[:severity] == :error }
      expect(errors.length).to eq 1
      expect(errors.first[:target]).to eq 'layer3__site-a-br-1__ge-0/0/2.0'
      expect(errors.first[:message]).to match(/mismatch its connected segment node prefix/)
    end
  end
end

RSpec.describe NetomoxExp::StaticVerifier::VerifyLogMessage do
  it 'normalizes severity names' do
    expect(described_class.new(severity: 'warning').severity).to eq :warn
    expect(described_class.new(severity: :err).severity).to eq :error
    expect(described_class.new(severity: 'FATAL').severity).to eq :fatal
    expect(described_class.new(severity: 'information').severity).to eq :info
  end

  it 'judges whether the message is as severe as the base severity or more' do
    warn_msg = described_class.new(severity: :warn)
    expect(warn_msg.upper_severity?(:warn)).to be true
    expect(warn_msg.upper_severity?(:info)).to be true
    expect(warn_msg.upper_severity?(:error)).to be false
  end

  it 'converts to hash' do
    expect(described_class.new(severity: :error, target: 't', message: 'm').to_hash)
      .to eq({ severity: :error, target: 't', message: 'm' })
  end
end
