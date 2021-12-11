# frozen_string_literal: true

require 'optparse'
require 'netomox'
require 'json'

def read_model_data(file)
  JSON.parse(File.read(file))
end

# rubocop:disable Metrics/MethodLength
def layer1_link_table(l1_nw)
  l1_nw.links.map.with_index do |link, i|
    src = link.source
    dst = link.destination
    {
      number: i + 1,
      src_node: src.node_ref,
      src_tp: src.tp_ref,
      dst_node: dst.node_ref,
      dst_tp: dst.tp_ref
    }
  end
end
# rubocop:enable Metrics/MethodLength

## main

opts = ARGV.getopts('i:', 'input:')
input_file = opts['i'] || opts['input']
unless input_file
  warn 'Input file is not specified'
  exit 1
end

raw_topology_data = read_model_data(input_file)
nws = Netomox::Topology::Networks.new(raw_topology_data)
l1_nw = nws.find_network('layer1')

puts ' , Source_Node, Source_Interface, Destination_Node, Destination_Interface, Source_Interface_Description'
layer1_link_table(l1_nw).each do |l|
  puts [
    l[:number],
    l[:src_node], l[:src_tp],
    l[:dst_node], l[:dst_tp],
    "to_#{l[:dst_node]}_#{l[:dst_tp]}"
  ].join(', ')
end
