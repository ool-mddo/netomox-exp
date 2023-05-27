# frozen_string_literal: true

require_relative 'table_base'

module NetomoxExp
  module TopologyBuilder
    module CSVMapper
      # row of ospf area configuration table
      class OspfAreaConfigurationTableRecord < TableRecordBase
        # @!attribute [rw] node
        #   @return [String]
        # @!attribute [rw] vrf
        #   @return [String]
        # @!attribute [rw] process_id
        #   @return [String]
        # @!attribute [rw] area # NOTICE: not dotted-quad
        #   @return [Integer]
        # @!attribute [rw] area_type
        #   @return [String]
        # @!attribute [rw] active_interfaces
        #   @return [Array<String>]
        # @!attribute [rw] passive_interfaces
        #   @return [Array<String>]
        attr_accessor :node, :vrf, :process_id, :area, :area_type, :active_interfaces, :passive_interfaces

        # @param [Enumerable] record A row of csv_mapper table
        def initialize(record)
          super()
          @node = record[:node]
          @vrf = record[:vrf]
          @process_id = record[:process_id]
          @area = record[:area]
          @area_type = record[:area_type]
          @active_interfaces = parse_interfaces(record[:active_interfaces])
          @passive_interfaces = parse_interfaces(record[:passive_interfaces])
        end

        # @return [String]
        def to_s
          [@node, @process_id, @area].map(&:to_s).join(', ')
        end

        private

        # rubocop:disable Security/Eval

        # @param [String] intfs_str A string of interface array
        # @return [Array<String>] Interface array
        def parse_interfaces(intfs_str)
          eval(intfs_str)
        end
        # rubocop:enable Security/Eval
      end

      # ospf area configuration table
      class OspfAreaConfigurationTable < TableBase
        # @param [String] target Target network (config) data name
        def initialize(target)
          super(target, 'ospf_area_conf.csv')
          @records = @orig_table.map { |r| OspfAreaConfigurationTableRecord.new(r) }
        end

        # @return [Array<Integer>] Areas in the network
        # TODO: vrf based search. Current: search default vrf ospf
        def all_areas
          @records.find_all { |r| r.vrf == 'default' }.map(&:area).sort.uniq
        end
      end
    end
  end
end
