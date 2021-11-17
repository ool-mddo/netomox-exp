# frozen_string_literal: true

require 'json'
require_relative 'l1_data_builder'
require_relative 'l2_data_builder'
require_relative 'l3_data_builder'
require_relative 'expanded_l3_data_builder'

# @param [Netomox::DSL::Networks] nws Networks
# @return [String] RFC8345-structure json string
def to_json(nws)
  JSON.pretty_generate(nws.topo_data)
end

# @param [Boolean] debug Debug mode
# @param [String] layer Target layer name
# @param [String, Integer] layer_id Layer number
# @return [Boolean]
def debug_layer?(debug, layer, layer_id)
  debug && !!(layer =~ /^l(?:ayer)?#{layer_id}$/i)
end

# rubocop:disable Metrics/AbcSize, Metrics/MethodLength

# @param [String] target Target source data (config file directory name)
# @param [String] layer Layer name to debug
# @param [Boolean] debug Debug mode (true if enable)
# @return [String] RFC8345-structure json string
def generate_json(target, layer: 'layer1', debug: false)
  l1_debug = debug_layer?(debug, layer, 1)
  l1_builder = L1DataBuilder.new(target: target, debug: l1_debug)
  layer1_nws = l1_builder.make_networks
  return layer1_nws.debug_print if l1_debug

  l2_debug = debug_layer?(debug, layer, 2)
  l2_builder = L2DataBuilder.new(
    target: target,
    layer1p: layer1_nws.find_network_by_name('layer1'),
    debug: l2_debug
  )
  layer2_nws = l2_builder.make_networks
  return layer2_nws.debug_print if l2_debug

  l3_debug = debug_layer?(debug, layer, 3)
  l3_builder = L3DataBuilder.new(
    target: target,
    layer2p: layer2_nws.find_network_by_name('layer2'),
    debug: l3_debug
  )
  layer3_nws = l3_builder.make_networks
  return layer3_nws.debug_print if l3_debug

  l3exp_debug = debug_layer?(debug, layer, '3p')
  l3exp_builder = ExpandedL3DataBuilder.new(
    layer3p: layer3_nws.find_network_by_name('layer3'),
    debug: l3exp_debug
  )
  layer3exp_nws = l3exp_builder.make_networks
  return layer3exp_nws.debug_print if l3exp_debug

  nws = [layer3exp_nws, layer3_nws, layer2_nws, layer1_nws]
  nmx_nws = Netomox::DSL::Networks.new
  nmx_nws.networks = nws.map(&:interpret).map(&:networks).flatten
  to_json(nmx_nws)
end
# rubocop:enable Metrics/AbcSize, Metrics/MethodLength
