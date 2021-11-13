# frozen_string_literal: true

require 'forwardable'
require_relative 'table_base'

# row of switch-vlan-properties table
class SwitchVlanPropsTableRecord < TableRecordBase
  attr_accessor :node, :vlan_id, :interfaces

  # @param [Enumerable] record A row of csv table (row)
  def initialize(record)
    super()
    @node = record[:node]
    @vlan_id = record[:vlan_id]
    @interfaces = extract_interfaces(record[:interfaces])
  end

  private

  # Convert interface list string to link-edge object.
  #   ( array of `node[interface]` format string to link-edge)
  # @param [String] interfaces_str Interface list string
  # @return [Array<EdgeBase>] Array of link-edge
  def extract_interfaces(interfaces_str)
    interfaces_str =~ /\[(.+)\]/
    content = Regexp.last_match(1)
    content.split(/,\s*/).map { |str| EdgeBase.new(str) }
  end
end

# switch-vlan-properties table
class SwitchVlanPropsTable < TableBase
  extend Forwardable

  def_delegators :@records, :each, :find, :[]

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
