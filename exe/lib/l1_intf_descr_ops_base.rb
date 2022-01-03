# frozen_string_literal: true

require 'json'
require 'netomox'

# layer1 interface description operations base
class L1InterfaceDescriptionOpsBase
  # @param [String] target_file Topology file path to find layer1 network
  def initialize(target_file)
    @l1_nw = read_layer1_network(target_file)
    return if @l1_nw

    warn "Error: 'layer1' network not found in #{target_file}"
    exit 1
  end

  private

  # @param [String] target_file Topology file path to find layer1 network
  # @return [Netomox::Topology::Network, nil] Layer1 network (nil if `layer1` network not found)
  def read_layer1_network(target_file)
    raw_topology_data = JSON.parse(File.read(target_file))
    nws = Netomox::Topology::Networks.new(raw_topology_data)
    nws.find_network('layer1')
  end
end
