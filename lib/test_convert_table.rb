# frozen_string_literal: true

require 'json'
require 'optparse'
require_relative 'convert_namespace/namespace_converter'

opts = ARGV.getopts('t:')

unless opts['t']
  warn 'Specify topology data with -t'
  exit 1
end

topology_file = opts['t']
topology_data = JSON.parse(File.read(topology_file))
converter = NetomoxExp::NamespaceConverter.new

# # create table
# converter.make_convert_table(topology_data)

# load from files
converter.load_origin_topology(topology_data)
ns_convert_table = JSON.parse(File.read('ns_convert_table.json'))
converter.reload_convert_table(ns_convert_table)

data = {
  node_name_table: converter.convert_table['node_name_table'],
  tp_name_table: converter.convert_table['tp_name_table'],
  ospf_proc_id_table: converter.convert_table['ospf_proc_id_table'],
  static_route_tp_table: converter.convert_table['static_route_tp_table']
}

# convert table
puts JSON.pretty_generate(data)

# converted config
puts JSON.pretty_generate(converter.convert)
