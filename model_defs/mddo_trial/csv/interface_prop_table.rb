# frozen_string_literal: true

require 'forwardable'
require_relative 'table_base'

# row of interface-properties table
class InterfacePropertiesTableRecord < TableRecordBase
  # @!attribute [rw] node
  #   @return [String]
  # @!attribute [rw] interface
  #   @return [String]
  # @!attribute [rw] vrf
  #   @return [String]
  # @!attribute [rw] primary_address
  #   @return [String]
  # @!attribute [rw] access_vlan
  #   @return [Integer]
  # @!attribute [rw] allowed_vlans
  #   @return [Array<Integer>]
  # @!attribute [rw] switchport
  #   @return [String]
  # @!attribute [rw] switchport_mode
  #   @return [String]
  # @!attribute [rw] channel_group
  #   @return [String]
  # @!attribute [rw] channel_group_members
  #   @return [Array<String>]
  attr_accessor :node, :interface, :vrf, :primary_address,
                :access_vlan, :allowed_vlans,
                :switchport, :switchport_mode,
                :channel_group, :channel_group_members

  alias lag_parent_interface channel_group
  alias lag_member_interfaces channel_group_members

  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize

  # @param [Enumerable] record A row of csv table
  def initialize(record)
    super()
    interface = EdgeBase.new(record[:interface])
    @node = interface.node
    @interface = interface.interface

    @access_vlan = record[:access_vlan]
    @allowed_vlans = parse_allowed_vlans(record[:allowed_vlans])
    @primary_address = record[:primary_address]
    @switchport = record[:switchport]
    @switchport_mode = record[:switchport_mode]
    @channel_group = record[:channel_group]
    @channel_group_members = interfaces2array(record[:channel_group_members])
    @vrf = record[:vrf]
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

  # @return [Boolean] true if the interface is switchport
  def switchport?
    !!(@switchport =~ /TRUE/i)
  end

  # @return [Boolean] true if the interface is routed port
  def routed_port?
    !!(!switchport? && @switchport_mode =~ /NONE/i && @primary_address)
  end

  # @return [Boolean] true if the interface is switchport-access
  def swp_access?
    !!(switchport? && @switchport_mode =~ /ACCESS/i)
  end

  # @return [Boolean] true if the interface is not switchport-trunk
  def almost_access?
    swp_access? || routed_port?
  end

  # @return [Boolean] true if the interface is switchport-trunk
  def swp_trunk?
    !!(switchport? && @switchport_mode =~ /TRUNK/i)
  end

  # @return [Boolean] true if LAG (parent) port
  def lag_parent?
    !@channel_group_members.empty?
  end

  # @return [Boolean] true if LAG member port (physical port)
  def lag_member?
    !@channel_group.nil?
  end

  # @return [String]
  def to_s
    "InterfacePropertiesTableRecord: #{@node}, #{@interface}"
  end

  private

  # rubocop:disable Security/Eval

  # @param [String] interfaces Multiple-interface string
  # @return [Array<String>] Array of interface
  def interfaces2array(interfaces)
    eval(interfaces).sort
  end
  # rubocop:enable Security/Eval

  # @param [String] range_str VLAN id range string
  # @return [Array<Integer>] List of VLAN id
  def vlan_range_to_array(range_str)
    if range_str =~ /(\d+)-(\d+)/
      md = Regexp.last_match
      return (md[1].to_i..md[2].to_i).to_a
    end

    [range_str.to_i]
  end

  # @param [String] vlans_str Multiple VLAN id string
  # @return [Array<Integer>] List of VLAN id
  def parse_allowed_vlans(vlans_str)
    # string to array
    case vlans_str
    when /^\d+$/
      # single number
      [vlans_str.to_i]
    when /^\d+-\d+$/
      # single range
      vlan_range_to_array(vlans_str)
    when /,/
      # multiple numbers and ranges
      vlans_str.split(',').map { |str| vlan_range_to_array(str) }.flatten
    else
      []
    end
  end
end

# interface-properties table
class InterfacePropertiesTable < TableBase
  extend Forwardable

  def_delegators :@records, :each, :find, :[]

  # @param [String] target Target network (config) data name
  def initialize(target)
    super(target, 'interface_props.csv')
    @records = @orig_table.map { |r| InterfacePropertiesTableRecord.new(r) }
  end

  # @param [String] node_name Node name
  # @param [String] intf_name Interface name
  # @return [nil, InterfacePropertiesTableRecord] Record if found or nil if not found
  def find_record_by_node_intf(node_name, intf_name)
    @records.find { |r| r.node == node_name && r.interface == intf_name }
  end
end
