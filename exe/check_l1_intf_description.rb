# frozen_string_literal: true

require 'optparse'
require 'netomox'
require 'json'

def correct_descr?(term_point, facing_edge)
  attr = term_point.attribute
  return false unless attr.respond_to?(:description) && attr.description =~ /to_(\S+)_(\S+)/

  descr_host = Regexp.last_match(1)
  descr_tp = Regexp.last_match(2)
  # ignore upper/loser case difference,
  # but abbreviated interface type is NOT allowed (e.g. GigabitEthernet0/0 <=> Gi0/0)
  descr_host&.downcase == facing_edge.node_ref.downcase && descr_tp&.downcase == facing_edge.tp_ref.downcase
end

## main

opts = ARGV.getopts('i:', 'input:')
input_file = opts['i'] || opts['input']
unless input_file
  warn 'Input file is not specified'
  exit 1
end

raw_topology_data = JSON.parse(File.read(input_file))
nws = Netomox::Topology::Networks.new(raw_topology_data)
l1_nw = nws.find_network('layer1')
unless l1_nw
  warn 'Layer1 network is not found in networks'
  exit 1
end

l1_nw.links.each do |link|
  # check only source interface because links are bidirectional
  src_tp = l1_nw.find_node_by_name(link.source.node_ref)&.find_tp_by_name(link.source.tp_ref)
  unless src_tp
    warn "term_point #{link.source} at link #{link} is not found"
    next
  end
  unless correct_descr?(src_tp, link.destination)
    warn "Found irregular description, or description not found: #{src_tp.path}"
  end
end
