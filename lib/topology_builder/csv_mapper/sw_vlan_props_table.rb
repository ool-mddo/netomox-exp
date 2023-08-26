# frozen_string_literal: true

require_relative 'table_base'

module NetomoxExp
  module TopologyBuilder
    module CSVMapper
      # row of switch-vlan-properties table
      class SwitchVlanPropsTableRecord < TableRecordBase
        # @!attribute [rw] node
        #   @return [String]
        # @!attribute [rw] vlan_id
        #   @return [Integer]
        # @!attribute [rw] interfaces
        #   @return [Array<String>]
        attr_accessor :node, :vlan_id, :interfaces

        # @param [Enumerable] record A row of csv_mapper table
        def initialize(record)
          super()
          @node = record[:node]
          @vlan_id = record[:vlan_id]
          @interfaces = extract_interfaces(record[:interfaces])
        end
      end

      # switch-vlan-properties table
      class SwitchVlanPropsTable < TableBase
        # @param [String] target Target network (config) data name
        def initialize(target)
          super(target, 'sw_vlan_props.csv')
          @records = @orig_table.map { |r| SwitchVlanPropsTableRecord.new(r) }
        end

        # @param [String] node_name Node name
        # @param [String] intf_name Interface name
        # @return [Array<SwitchVlanPropsTableRecord>] Found records
        def find_all_records_by_node_intf(node_name, intf_name)
          @records.find_all do |r|
            r.node == node_name && r.interfaces.map(&:interface).include?(intf_name)
          end
        end

        # @param [String] node_name Node name
        # @param [String] intf_name Interface name
        # @return [nil, InterfacePropertiesTableRecord] Record if found or nil if not found
        def find_record_by_node_intf(node_name, intf_name)
          @records.find do |r|
            r.node == node_name && r.interfaces.map(&:interface).include?(intf_name)
          end
        end
      end
    end
  end
end
