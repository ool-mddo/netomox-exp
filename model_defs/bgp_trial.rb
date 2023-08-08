# frozen_string_literal: true

require 'json'
require 'netomox'
require_relative 'bgp_trial/bgp_as'
require_relative 'bgp_trial/bgp_ext'
require_relative 'bgp_trial/layer3_ext'

nws = Netomox::DSL::Networks.new

register_layer3_external(nws)
register_bgp_external(nws)
register_bgp_as(nws)

puts JSON.pretty_generate(nws.topo_data)
