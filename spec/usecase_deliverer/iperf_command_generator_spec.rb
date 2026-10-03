# frozen_string_literal: true

require 'lib/usecase_deliverer/iperf_command_generator'

RSpec.describe NetomoxExp::UsecaseDeliverer::IperfCommandGenerator do
  let(:usecase_params) { { 'expected_traffic' => { 'emulated_traffic' => { 'scale' => '0.5' } } } }
  let(:flows) do
    [
      { 'source' => '10.0.1.0/24', 'dest' => '10.0.9.0/24', 'rate' => '20' },
      { 'source' => '10.0.2.0/24', 'dest' => '10.0.9.0/24', 'rate' => '10' },
      { 'source' => '10.0.9.0/24', 'dest' => '10.0.1.0/24', 'rate' => '4' }
    ]
  end

  def endpoint(node, ip)
    { 'node' => node, 'interfaces' => [{ 'attribute' => { 'ip-address' => ["#{ip}/24"] } }] }
  end

  let(:endpoints) do
    [endpoint('ep-b', '10.0.2.100'), endpoint('ep-a', '10.0.1.100'), endpoint('ep-z', '10.0.9.100')]
  end
  let(:commands) { described_class.new(usecase_params, flows, endpoints).generate_iperf_commands }

  it 'groups clients by server node, sorted by server node name' do
    expect(commands.map { |c| c['server_node'] }).to eq %w[ep-a ep-z]
  end

  it 'sorts clients by node name and assigns port numbers from 5201' do
    server = commands.find { |c| c['server_node'] == 'ep-z' }
    expect(server['clients'].map { |c| c['client_node'] }).to eq %w[ep-a ep-b]
    expect(server['clients'].map { |c| c['server_port'] }).to eq [5201, 5202]
  end

  it 'resolves the server address from the destination endpoint' do
    server = commands.find { |c| c['server_node'] == 'ep-z' }
    expect(server['clients'].map { |c| c['server_address'] }).to all(eq('10.0.9.100'))
  end

  it 'converts rate (Mbps -> Kbps) and applies the scale' do
    server = commands.find { |c| c['server_node'] == 'ep-z' }
    expect(server['clients'].map { |c| c['rate'] }).to eq [20 * 1e3 * 0.5, 10 * 1e3 * 0.5]
  end
end
