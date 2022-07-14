require 'json'
require 'netomox'
require_relative 'ospf_trial/layer1'
require_relative 'ospf_trial/layer2'
require_relative 'ospf_trial/layer3'
require_relative 'ospf_trial/ospf1'

nws = Netomox::DSL::Networks.new

register_ospf1(nws)
register_layer3(nws)
register_layer2(nws)
register_layer1(nws)

puts JSON.pretty_generate(nws.topo_data)
