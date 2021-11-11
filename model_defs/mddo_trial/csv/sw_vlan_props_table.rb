# frozen_string_literal: true

require 'forwardable'
require_relative 'table_base'

# row of switch-vlan-properties table
class SwitchVlanPropsTableRecord < TableRecordBase
  attr_accessor :node, :vlan_id, :interfaces

  def initialize(record)
    super()
    @node = record[:node]
    @vlan_id = record[:vlan_id]
    @interfaces = extract_interfaces(record[:interfaces])
  end

  def l2node_name
    "#{@node}_VL#{@vlan_id}"
  end

  private

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

  def initialize(target)
    super(target, 'sw_vlan_props.csv')
    @records = @orig_table.map { |r| SwitchVlanPropsTableRecord.new(r) }
  end

  def find_all_records_by_node_intf(node_name, intf_name)
    @records.find_all do |r|
      r.node == node_name && r.interfaces.map(&:interface).include?(intf_name)
    end
  end

  # alias
  def find_record_by_node_intf(node_name, intf_name)
    find_node_int(node_name, intf_name)
  end

  def find_node_int(node, interface)
    @records.find do |r|
      r.node == node && r.interfaces.map(&:interface).include?(interface)
    end
  end
end
