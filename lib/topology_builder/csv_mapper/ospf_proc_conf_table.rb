# frozen_string_literal: true

require_relative 'table_base'

module NetomoxExp
  module TopologyBuilder
    module CSVMapper
      # row of ospf process configuration table
      class OspfProcessConfigurationTableRecord < TableRecordBase
        # @!attribute [rw] node
        #   @return [String]
        # @!attribute [rw] vrf
        #   @return [String]
        # @!attribute [rw] process_id
        #   @return [String]
        # @!attribute [rw] areas # NOTICE: area id is not dotted-quad
        #   @return [Array<Integer>]
        # @!attribute [rw] router_id
        #   @return [String]
        # @!attribute [rw] export_policy_sources
        #   @return [Array<String>]
        attr_accessor :node, :vrf, :process_id, :areas, :router_id, :export_policy_sources

        # @param [Enumerable] record A row of csv_mapper table
        def initialize(record)
          super()
          @node = record[:node]
          @vrf = record[:vrf]
          @process_id = record[:process_id]
          @areas = parse_array_string(record[:areas]).map(&:to_i)
          @router_id = record[:router_id]
          @export_policy_sources = parse_array_string(record[:export_policy_sources])
          @area_border_router = record[:area_border_router]
        end

        # @return [Boolean] true if the process is area border
        def area_border_router?
          !!(@area_border_router =~ /true/i)
        end
        alias area_border_router area_border_router?
      end

      # ospf process configuration table
      class OspfProcessConfigurationTable < TableBase
        # @param [String] target Target network (config) data name
        def initialize(target)
          super(target, 'ospf_proc_conf.csv')
          @records = @orig_table.map { |r| OspfProcessConfigurationTableRecord.new(r) }
        end

        # @param [String] node_name Node name to find
        # @return [OspfProcessConfigurationTableRecords,nil] Found record
        def find_record_by_node(node_name)
          @records.find { |r| r.node == node_name }
        end
      end
    end
  end
end
