# frozen_string_literal: true

require_relative 'node_name_table'
require_relative 'term_point_name_table'
require_relative 'ospf_proc_id_table'
require_relative 'static_route_tp_table'

module NetomoxExp
  # convert table
  class NamespaceConvertTable
    attr_reader :node_name_table, :tp_name_table, :ospf_proc_id_table, :static_route_tp_table
    alias node_name node_name_table
    alias tp_name tp_name_table
    alias ospf_proc_id ospf_proc_id_table
    alias static_route_tp static_route_tp_table

    def initialize

      # convert tables
      @node_name_table = NodeNameTable.new
      @tp_name_table = TermPointNameTable.new(@node_name_table)
      @ospf_proc_id_table = OspfProcIdTable.new(@node_name_table)
      @static_route_tp_table = StaticRouteTpTable.new(@node_name_table)
    end

    # @return [Hash]
    def to_hash
      {
        'node_name_table' => @node_name_table.to_data,
        'tp_name_table' => @tp_name_table.to_data,
        'ospf_proc_id_table' => @ospf_proc_id_table.to_data,
        'static_route_tp_table' => @static_route_tp_table.to_data
      }
    end

    # @param [Hash] topology_data Topology data (RFC8345 Hash)
    # @return [void]
    def load_from_topology(topology_data)
      src_nws = Netomox::Topology::Networks.new(topology_data)

      @node_name_table.make_table(src_nws) # MUST at first (in use making other tables)
      @tp_name_table.make_table(src_nws)
      @ospf_proc_id_table.make_table(src_nws)
      @static_route_tp_table.make_table(src_nws)
    end

    # @param [Hash] given_table_data Convert table data
    # @return [void]
    def reload(given_table_data)
      @node_name_table.load_table(given_table_data['node_name_table'])
      @tp_name_table.load_table(given_table_data['tp_name_table'])
      @ospf_proc_id_table.load_table(given_table_data['ospf_proc_id_table'])
      @static_route_tp_table.load_table(given_table_data['static_route_tp_table'])
    end
  end
end
