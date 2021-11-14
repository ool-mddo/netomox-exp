# frozen_string_literal: true

require 'forwardable'
require_relative 'table_base'

# row of node-properties table
class NodePropsTableRecord < TableRecordBase
  # @!attribute [rw] node
  #   @return [String]
  # @!attribute [rw] config_format
  #   @return [String]
  # @!attribute [rw] interfaces
  #   @return [Array<String>]
  # @!attribute [rw] vrfs
  #   @return [String]
  #   TODO: Array<String>
  attr_accessor :node, :config_format, :interfaces, :vrfs

  # @param [Enumerable] record A row of csv table
  def initialize(record)
    super()
    @node = record[:node]
    @config_format = record[:configuration_format]
    @interfaces = interfaces2array(record[:interfaces])
    @vrfs = record[:vrfs]
  end

  # @return [Array<String>] A list of physical interface
  def physical_interfaces
    # use physical interface (ignore SVI)
    @interfaces.filter { |d| d !~ /Vlan*/ }
  end

  # @return [Boolean] true if this node is host
  def host?
    @config_format == 'HOST'
  end

  # @return [Boolean] true if this node is network device
  def switch?
    %w[CISCO_IOS].include?(@config_format)
  end

  private

  # rubocop:disable Security/Eval
  def interfaces2array(interfaces)
    eval(interfaces).sort
  end
  # rubocop:enable Security/Eval
end

# node-properties table
class NodePropsTable < TableBase
  extend Forwardable

  def_delegators :@records, :each, :find, :[]

  # @param [String] target Target network (config) data name
  def initialize(target)
    super(target, 'node_props.csv')
    @records = @orig_table.map { |r| NodePropsTableRecord.new(r) }
  end

  # @param [String] node_name Node name
  # @return [nil, InterfacePropertiesTableRecord] Record if found or nil if not found
  def find_record_by_node(node_name)
    @records.find { |r| r.node == node_name }
  end
end
