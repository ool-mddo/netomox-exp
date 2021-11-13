# frozen_string_literal: true

require 'json'
# require 'pry'
require_relative 'layer1p'
require_relative 'layer2p'
require_relative 'layer3p'

def to_json(nws)
  JSON.pretty_generate(nws.topo_data)
end

def debug_layer?(debug, layer, layer_num)
  debug && layer =~ /l(?:ayer)?#{layer_num}/i
end

# rubocop:disable Metrics/AbcSize, Metrics/MethodLength
def generate_json(target, layer: 'layer1', debug: false)
  l1_builder = L1DataBuilder.new(target)
  layer1p = l1_builder.make_networks
  return layer1p.dump if debug_layer?(debug, layer, 1)

  l2_builder = L2DataBuilder.new(target, layer1p.find_network_by_name('layer1'))
  layer2p = l2_builder.make_networks
  return layer2p.dump if debug_layer?(debug, layer, 2)

  l3_builder = L3DataBuilder.new(target, layer2p.find_network_by_name('layer2'))
  layer3p = l3_builder.make_networks
  return layer3p.dump if debug_layer?(debug, layer, 3)

  nws = Netomox::DSL::Networks.new
  nws.networks = [layer3p, layer2p, layer1p].map(&:interpret).map(&:networks).flatten
  # binding.pry # debug
  to_json(nws)
end
# rubocop:enable Metrics/AbcSize, Metrics/MethodLength
