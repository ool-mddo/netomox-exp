# frozen_string_literal: true

require 'json'
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
  opts = { target: target, debug: debug }

  l1_builder = L1DataBuilder.new(**opts)
  layer1_nws = l1_builder.make_networks
  return layer1_nws.debug_print if debug_layer?(debug, layer, 1)

  opts[:layer1p] = layer1_nws.find_network_by_name('layer1')
  l2_builder = L2DataBuilder.new(**opts)
  layer2_nws = l2_builder.make_networks
  return layer2_nws.debug_print if debug_layer?(debug, layer, 2)

  opts.delete(:layer1p)
  opts[:layer2p] = layer2_nws.find_network_by_name('layer2')
  l3_builder = L3DataBuilder.new(**opts)
  layer3_nws = l3_builder.make_networks
  return layer3_nws.debug_print if debug_layer?(debug, layer, 3)

  nws = Netomox::DSL::Networks.new
  nws.networks = [layer3_nws, layer2_nws, layer1_nws].map(&:interpret).map(&:networks).flatten
  to_json(nws)
end
# rubocop:enable Metrics/AbcSize, Metrics/MethodLength
