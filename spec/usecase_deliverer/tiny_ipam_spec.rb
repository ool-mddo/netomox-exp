# frozen_string_literal: true

require 'lib/usecase_deliverer/external_as_topology/tiny_ipam'

RSpec.describe NetomoxExp::UsecaseDeliverer::TinyIPAM do
  let(:ipam) { described_class.instance }

  before do
    ipam.assign_base_prefix('10.1.0.0/16')
  end

  after { ipam.assign_base_prefix('169.254.0.0/16') }

  it 'is a singleton' do
    expect(described_class.instance).to equal ipam
  end

  describe '#assign_base_prefix' do
    it 'resets counters when a new base prefix is assigned' do
      ipam.count_link
      ipam.count_loopback
      ipam.assign_base_prefix('10.2.0.0/16')
      expect([ipam.link_count, ipam.loopback_count]).to eq [0, 0]
    end

    it 'does not accept a prefix smaller than /23 (keeps the previous one)' do
      expect { ipam.assign_base_prefix('10.3.0.0/24') }.to output(/too small/).to_stderr
      expect(ipam.loopback_ip_of_index(0).to_s).to eq '10.1.0.0'
    end
  end

  describe 'loopback addresses' do
    it 'assigns /32 addresses in the first /24 block' do
      expect(ipam.ip_and_prefix_str(ipam.loopback_ip_of_index(0))).to eq '10.1.0.0/32'
      expect(ipam.ip_and_prefix_str(ipam.loopback_ip_of_index(255))).to eq '10.1.0.255/32'
    end

    it 'raises error on overflow (>= 256)' do
      expect { ipam.loopback_ip_of_index(256) }.to raise_error(StandardError, /Loopback address overflow/)
    end

    it 'follows the loopback counter' do
      ipam.count_loopback
      ipam.count_loopback
      expect(ipam.current_loopback_ip_str).to eq '10.1.0.2/32'
    end
  end

  describe 'link addresses' do
    it 'assigns /30 blocks after the loopback block (x.x.1.0/24~)' do
      expect(ipam.ip_and_prefix_str(ipam.link_ip_of_index(0))).to eq '10.1.1.0/30'
      expect(ipam.ip_and_prefix_str(ipam.link_ip_of_index(1))).to eq '10.1.1.4/30'
      expect(ipam.ip_and_prefix_str(ipam.link_ip_of_index(63))).to eq '10.1.1.252/30'
      expect(ipam.ip_and_prefix_str(ipam.link_ip_of_index(64))).to eq '10.1.2.0/30'
    end

    it 'assigns unique link prefixes' do
      prefixes = (0...500).map { |i| ipam.link_ip_of_index(i).to_s }
      expect(prefixes.uniq.length).to eq 500
    end

    it 'raises error on overflow' do
      expect { ipam.link_ip_of_index(64 * 255) }.to raise_error(StandardError, /Link address overflow/)
    end

    it 'gives two host addresses of the current link' do
      ipam.count_link
      expect(ipam.current_link_intf_ip_str_pair).to eq ['10.1.1.5/30', '10.1.1.6/30']
    end
  end
end
