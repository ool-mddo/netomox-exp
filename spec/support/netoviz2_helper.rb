# frozen_string_literal: true

require 'netomox'
require 'lib/netoviz2/model'

# helpers for netoviz2 specs
module Netoviz2Helper
  # @return [Hash] a small multi-layer topology (RFC8345 + mddo-topology) for netoviz2 specs
  #   - layer1: nodes with `/` in names, bidirectional links
  #   - layer2: declares layer1 as supporting-network, tp/node supports to layer1
  #   - layer3: does NOT declare supporting-network but refers to layer2 (declaration mismatch),
  #             has one dangling node support
  #   - bgp_proc: declares a supporting-network that does not exist
  def self.tiny_topology
    {
      'ietf-network:networks' => {
        'mddo-topology:networks-attributes' => { 'flag' => ['blueprint=sample1'] },
        'network' => [layer1, layer2, layer3, bgp_proc]
      }
    }
  end

  def self.tp(name, supports: nil, attr: nil)
    data = { 'tp-id' => name }
    data['supporting-termination-point'] = supports if supports
    data['mddo-topology:l3-termination-point-attributes'] = attr if attr
    data
  end

  def self.link(src_node, src_tp, dst_node, dst_tp)
    { 'link-id' => [src_node, src_tp, dst_node, dst_tp].join(','),
      'source' => { 'source-node' => src_node, 'source-tp' => src_tp },
      'destination' => { 'dest-node' => dst_node, 'dest-tp' => dst_tp } }
  end

  def self.layer1
    { 'network-id' => 'layer1', 'network-types' => { 'mddo-topology:l1-network' => {} },
      'node' => [
        { 'node-id' => 'sw/1',
          'ietf-network-topology:termination-point' => [tp('ge-0/0/1'), tp('ge-0/0/2')] },
        { 'node-id' => 'sw2', 'ietf-network-topology:termination-point' => [tp('p1')] }
      ],
      'ietf-network-topology:link' => [link('sw/1', 'ge-0/0/1', 'sw2', 'p1'), link('sw2', 'p1', 'sw/1', 'ge-0/0/1')] }
  end

  def self.layer2
    { 'network-id' => 'layer2', 'network-types' => { 'mddo-topology:l2-network' => {} },
      'supporting-network' => [{ 'network-ref' => 'layer1' }],
      'node' => [
        { 'node-id' => 'sw/1', 'supporting-node' => [{ 'network-ref' => 'layer1', 'node-ref' => 'sw/1' }],
          'ietf-network-topology:termination-point' => [
            tp('ge-0/0/1', supports: [{ 'network-ref' => 'layer1', 'node-ref' => 'sw/1', 'tp-ref' => 'ge-0/0/1' }])
          ] }
      ],
      'ietf-network-topology:link' => [] }
  end

  def self.layer3
    { 'network-id' => 'layer3', 'network-types' => { 'mddo-topology:l3-network' => {} },
      'node' => [layer3_router1, layer3_router2], 'ietf-network-topology:link' => [] }
  end

  def self.layer3_router1
    { 'node-id' => 'r1', 'mddo-topology:l3-node-attributes' => { 'node-type' => 'node' },
      'supporting-node' => [{ 'network-ref' => 'layer2', 'node-ref' => 'sw/1' }],
      'ietf-network-topology:termination-point' => [
        tp('ge-0/0/1.0', attr: { 'description' => 'to sw' },
                         supports: [{ 'network-ref' => 'layer2', 'node-ref' => 'sw/1', 'tp-ref' => 'ge-0/0/1' }])
      ] }
  end

  # has a dangling node support
  def self.layer3_router2
    { 'node-id' => 'r2', 'supporting-node' => [{ 'network-ref' => 'layer2', 'node-ref' => 'not-found' }],
      'ietf-network-topology:termination-point' => [] }
  end

  def self.bgp_proc
    { 'network-id' => 'bgp_proc', 'network-types' => { 'mddo-topology:bgp-proc-network' => {} },
      'supporting-network' => [{ 'network-ref' => 'layer9' }],
      'node' => [], 'ietf-network-topology:link' => [] }
  end

  # @param [Hash] data Topology data (RFC8345)
  # @return [NetomoxExp::Netoviz2::Model]
  def build_model(data)
    NetomoxExp::Netoviz2::Model.new(Netomox::Topology::Networks.new(data))
  end

  # @return [Hash] deep copy of tiny topology
  def tiny_topology
    FixtureHelper.deep_dup(Netoviz2Helper.tiny_topology)
  end
end
