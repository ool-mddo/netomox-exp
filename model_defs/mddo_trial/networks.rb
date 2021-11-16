# frozen_string_literal: true

require 'json'
require_relative 'layer1p'
require_relative 'layer2p'
require_relative 'layer3p'
require_relative 'layer3p_expand'

def to_json(nws)
  JSON.pretty_generate(nws.topo_data)
end

# @param [Boolean] debug Debug mode
# @param [String] layer Target layer name
# @param [String, Integer] layer_id Layer number
def debug_layer?(debug, layer, layer_id)
  debug && layer =~ /^l(?:ayer)?#{layer_id}$/i
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

  opts.delete(:layer2p)
  opts[:layer3p] = layer3_nws.find_network_by_name('layer3')
  l3exp_builder = ExpandedL3DataBuilder.new(**opts)
  layer3exp_nws = l3exp_builder.make_networks
  return layer3exp_nws.debug_print if debug_layer?(debug, layer, '3p')

  nws = [layer3exp_nws, layer3_nws, layer2_nws, layer1_nws]
  nmx_nws = Netomox::DSL::Networks.new
  nmx_nws.networks = nws.map(&:interpret).map(&:networks).flatten
  to_json(nmx_nws)
end
# rubocop:enable Metrics/AbcSize, Metrics/MethodLength
