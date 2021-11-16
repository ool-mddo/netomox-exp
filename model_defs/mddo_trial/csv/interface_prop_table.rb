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
  # @!attribute [rw] switchport_encap
  #   @return [String]
  attr_accessor :node, :interface, :vrf, :primary_address,
                :access_vlan, :allowed_vlans,
                :switchport, :switchport_mode, :switchport_encap

  # rubocop:disable Metrics/MethodLength

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
    @switchport_encap = record[:switchport_trunk_encapsulation]
    @vrf = record[:vrf]
  end
  # rubocop:enable Metrics/MethodLength

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

  # @return [Array<Integer>] List of VLAN id
  def swp_vlans
    return [] unless switchport?

    swp_access? ? [@access_vlan] : @allowed_vlans
  end

  # @param [Integer] vlan_id VLAN id
  # @return [Boolean] true if the VLAN_id is included switchport vlan config
  def swp_has_vlan?(vlan_id)
    swp_vlans.include?(vlan_id)
  end

  # @return [String]
  def to_s
    "InterfacePropertiesTableRecord: #{@node}, #{@interface}"
  end

  private

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
