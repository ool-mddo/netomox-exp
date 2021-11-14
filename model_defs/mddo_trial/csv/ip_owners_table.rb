# frozen_string_literal: true

require 'forwardable'
require_relative 'table_base'

# row of ip-owners table
class IPOwnersTableRecord < TableRecordBase
  # @!attribute [rw] node
  #   @return [String]
  # @!attribute [rw] vrf
  #   @return [String]
  # @!attribute [rw] interface
  #   @return [String]
  # @!attribute [rw] ip
  #   @return [String]
  # @!attribute [rw] mask
  #   @return [Integer]
  # @!attribute [rw] active
  #   @return [String]
  attr_accessor :node, :vrf, :interface, :ip, :mask, :active

  # @param [Enumerable] record A row of csv table
  def initialize(record)
    super()
    @node = record[:node]
    @vrf = record[:vrf]
    @interface = record[:interface]
    @ip = record[:ip]
    @mask = record[:mask]
    @active = record[:active]
  end

  # @return [String]
  def to_s
    [@node, @vrf, @interface, @ip, @mask].map(&:to_s).join(', ')
  end
end

# ip-owners table
class IPOwnersTable < TableBase
  extend Forwardable

  def_delegators :@records, :each, :find, :[]

  # @param [String] target Target network (config) data name
  def initialize(target)
    super(target, 'ip_owners.csv')
    @records = @orig_table.map { |r| IPOwnersTableRecord.new(r) }
  end

  # @param [String] node_name Node name
  # @param [String] intf_name Interface name
  # @return [nil, IPOwnersTableRecord] Record if found or nil if not found
  def find_record_by_node_intf(node_name, intf_name)
    @records.find { |r| r.node == node_name && r.interface == intf_name }
  end

  # @param [String] node_name Node name
  # @return [Array<IPOwnersTableRecord>] Found records
  def find_all_records_by_node(node_name)
    @records.find_all { |r| r.node == node_name }
  end

  # @param [String] node_name Node name
  # @param [Integer] vlan_id VLAN id of vlan_interface
  # @return [nil, IPOwnersTableRecord] Record if found or nil if not found
  def find_vlan_intf_record_by_node(node_name, vlan_id)
    find_all_records_by_node(node_name).find do |rec|
      rec.ip && rec.interface =~ /Vlan#{vlan_id}/i
    end
  end
end
