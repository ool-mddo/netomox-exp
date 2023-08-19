# frozen_string_literal: true

require 'json'
require 'netomox'
require_relative 'namespace_converter_base'
require_relative 'node_name_table'
require_relative 'term_point_name_table'
require_relative 'ospf_proc_id_table'
require_relative 'static_route_tp_table'

module NetomoxExp
  # convert table
  class NamespaceConvertTable < NamespaceConverterBase
    attr_reader :node_name_table, :tp_name_table

    def initialize
      super
      # convert tables
      @node_name_table = NodeNameTable.new
      @tp_name_table = TermPointNameTable.new(@node_name_table)
      @ospf_proc_id_table = OspfProcIdTable.new(@node_name_table)
      @static_route_tp_table = StaticRouteTpTable.new(@node_name_table)
    end

    # @return [Hash]
    def convert_table
      {
        'node_name_table' => @node_name_table.to_data,
        'tp_name_table' => @tp_name_table.to_data,
        'ospf_proc_id_table' => @ospf_proc_id_table.to_data,
        'static_route_tp_table' => @static_route_tp_table.to_data
      }
    end

    # @param [Netomox::Topology::Networks] topology_data Topology data
    # @return [void]
    def make_convert_table(topology_data)
      load_origin_topology(topology_data)

      @node_name_table.make_table(@src_nws) # MUST at first (in use making other tables)
      @tp_name_table.make_table(@src_nws)
      @ospf_proc_id_table.make_table(@src_nws)
      @static_route_tp_table.make_table(@src_nws)
    end

    # @param [Hash] given_table_data Convert table data
    # @return [void]
    def reload_convert_table(given_table_data)
      @node_name_table.load_table(given_table_data['node_name_table'])
      @tp_name_table.load_table(given_table_data['tp_name_table'])
      @ospf_proc_id_table.load_table(given_table_data['ospf_proc_id_table'])
      @static_route_tp_table.load_table(given_table_data['static_route_tp_table'])
    end
  end
end
