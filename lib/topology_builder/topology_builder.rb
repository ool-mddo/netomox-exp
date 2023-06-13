# frozen_string_literal: true

require_relative 'l1_data_builder'
require_relative 'l2_data_builder'
require_relative 'l3_data_builder'
require_relative 'expanded_l3_data_builder'
require_relative 'ospf_data_builder'
require_relative 'bgp_data_builder'

module NetomoxExp
  # Topology data builder
  module TopologyBuilder
    module_function

    # @param [Array<Netomox::PseudoDSL::PNetworks>] nws Networks
    # @return [Hash] RFC8345 topology data
    def to_data(nws)
      nmx_nws = Netomox::DSL::Networks.new
      nmx_nws.networks = nws.map(&:interpret).map(&:networks).flatten
      nmx_nws.topo_data
    end

    # @param [Boolean] debug Debug mode
    # @param [String] layer Target layer name
    # @param [String, Integer] layer_id Layer number
    # @return [Boolean]
    def debug_layer?(debug, layer, layer_id)
      debug && !!(layer =~ /^l(?:ayer)?_?#{layer_id}$/i)
    end

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength

    # @param [String] target Target source data (config file directory name)
    # @param [String] layer Layer name to debug
    # @param [Boolean] debug Debug mode (true if enable)
    # @return [Hash] RFC8345 topology data
    def generate_data(target, layer: 'layer1', debug: false)
      l1_debug = debug_layer?(debug, layer, 1)
      l1_builder = L1DataBuilder.new(target:, debug: l1_debug)
      layer1_nws = l1_builder.make_networks
      if l1_debug
        layer1_nws.dump
        return to_data([layer1_nws])
      end

      l2_debug = debug_layer?(debug, layer, 2)
      l2_builder = L2DataBuilder.new(
        target:,
        layer1p: layer1_nws.find_network_by_name('layer1'),
        debug: l2_debug
      )
      layer2_nws = l2_builder.make_networks
      if l2_debug
        layer2_nws.dump
        return to_data([layer2_nws, layer1_nws])
      end

      l3_debug = debug_layer?(debug, layer, 3)
      l3_builder = L3DataBuilder.new(
        target:,
        layer2p: layer2_nws.find_network_by_name('layer2'),
        debug: l3_debug
      )
      layer3_nws = l3_builder.make_networks
      if l3_debug
        layer3_nws.dump
        return to_data([layer3_nws, layer2_nws, layer1_nws])
      end

      l3exp_debug = debug_layer?(debug, layer, '3p')
      l3exp_builder = ExpandedL3DataBuilder.new(
        layer3p: layer3_nws.find_network_by_name('layer3'),
        debug: l3exp_debug
      )
      layer3exp_nws = l3exp_builder.make_networks
      if l3exp_debug
        layer3exp_nws.dump
        to_data([layer3exp_nws, layer3_nws, layer2_nws, layer1_nws])
      end

      ospf_debug = debug_layer?(debug, layer, 'ospf')
      ospf_builder = OspfDataBuilder.new(
        target:,
        layer3p: layer3_nws.find_network_by_name('layer3'),
        debug: ospf_debug
      )
      ospf_nws = ospf_builder.make_networks
      ospf_nws.dump if ospf_debug
      to_data([ospf_nws, layer3_nws, layer2_nws, layer1_nws])

      bgp_debug = debug_layer?(debug, layer, 'bgp')
      bgp_builder = BgpDataBuilder.new(
        target:,
        layer3p: layer3_nws.find_network_by_name('layer3'),
        debug: bgp_debug
      )
      bgp_nws = bgp_builder.make_networks
      bgp_nws.dump if bgp_debug
      to_data([bgp_nws, ospf_nws, layer3_nws, layer2_nws, layer1_nws])
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
  end
end
