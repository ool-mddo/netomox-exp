# frozen_string_literal: true

require_relative 'table_base'

module TopologyBuilder
  module CSVMapper
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
      # @!attribute [rw] switchport_trunk_encapsulation
      #   @return [String]
      # @!attribute [rw] channel_group
      #   @return [String]
      # @!attribute [rw] channel_group_members
      #   @return [Array<String>]
      # @!attribute [rw] description
      #   @return [String]
      attr_accessor :node, :interface, :vrf, :primary_address,
                    :access_vlan, :allowed_vlans,
                    :switchport, :switchport_mode, :switchport_trunk_encapsulation,
                    :channel_group, :channel_group_members, :description

      alias lag_parent_interface channel_group
      alias lag_member_interfaces channel_group_members
      alias trunk_encap switchport_trunk_encapsulation

      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize

      # @param [Enumerable] record A row of csv_mapper table
      def initialize(record)
        super()
        interface = EdgeBase.new(record[:interface])
        @node = interface.node
        @interface = interface.interface

        @active = record[:active]
        @access_vlan = record[:access_vlan]
        @allowed_vlans = parse_allowed_vlans(record[:allowed_vlans])
        @primary_address = record[:primary_address]
        @switchport = record[:switchport]
        @switchport_mode = record[:switchport_mode]
        @switchport_trunk_encapsulation = record[:switchport_trunk_encapsulation]
        @channel_group = record[:channel_group]
        @channel_group_members = interfaces2array(record[:channel_group_members])
        @description = record[:description]
        @vrf = record[:vrf]
      end
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

      # @return [Boolean] true if the interface is active
      def active?
        true_string?(@active)
      end
      alias active active?

      # @return [Boolean] true if the interface is switchport
      def switchport?
        true_string?(@switchport)
      end
      # DO NOT alias #switchport/#switchport? to keep #switchport writable.

      # @return [Boolean] true if the interface is routed port
      def routed_port?
        !switchport? && @switchport_mode.downcase == 'none' && !@primary_address.nil? && !@primary_address.empty?
      end

      # @return [Boolean] true if the interface is switchport-access
      def swp_access?
        switchport? && @switchport_mode.downcase == 'access'
      end

      # @return [Boolean] true if the interface is not switchport-trunk
      def almost_access?
        swp_access? || routed_port?
      end

      # @return [Boolean] true if the interface is switchport-trunk
      def swp_trunk?
        switchport? && @switchport_mode.downcase == 'trunk'
      end

      # @return [Boolean] true if LAG (parent) port
      def lag_parent?
        !@channel_group_members.empty?
      end

      # @return [Boolean] true if LAG member port (physical port)
      def lag_member?
        !@channel_group.nil?
      end

      # Unit interface number (for junos interface)
      # @return [nil, String] unit number string
      def unit_number
        %r{[\w\-/]+\d+\.(\d+)}.match(interface).to_a[1]
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

      # rubocop:disable Metrics/MethodLength

      # @param [String,Integer] vlans Multiple VLAN id string (or a number for single vlan)
      # @return [Array<Integer>] List of VLAN id
      # @raise StandardError Invalid vlan string format
      def parse_allowed_vlans(vlans)
        # string to array
        case vlans
        when /,/
          # multiple numbers and ranges
          vlans.split(',').map { |str| parse_allowed_vlans(str) }.flatten
        when /^(\d+)-(\d+)$/
          # single range
          md = Regexp.last_match
          (md[1].to_i..md[2].to_i).to_a
        when /^\d+$/, Integer
          # single number
          # NOTE: the "Allowed_VLANs" column in interface_props.csv (batfish output) contains
          # single vlan (a number) as Integer, multiple vlans (like "A,B,C-D") as String.
          [vlans.to_i]
        when '', nil, /^\s*$/
          # empty
          []
        else
          raise StandardError, "Error: Invalid vlan string: /#{vlans}/"
        end
      end
      # rubocop:enable Metrics/MethodLength
    end

    # interface-properties table
    class InterfacePropertiesTable < TableBase
      # @param [String] target Target network (config) data name
      def initialize(target)
        super(target, 'interface_props.csv')
        @records = @orig_table.map { |r| InterfacePropertiesTableRecord.new(r) }
      end

      # @param [String] node_name Node name
      # @return [Array<InterfacePropertiesTableRecord>] Records
      def find_all_records_by_node(node_name)
        @records.find_all { |r| r.node == node_name }
      end

      # @param [String] node_name Node name
      # @param [String] intf_name Interface name
      # @return [nil, InterfacePropertiesTableRecord] Record if found or nil if not found
      def find_record_by_node_intf(node_name, intf_name)
        @records.find { |r| r.node == node_name && r.interface == intf_name }
      end

      # For junos, find all unit interface property of physical interface
      # @param [String] node_name Node name
      # @param [String] intf_name Interface name (physical interface)
      # @return [Array<InterfacePropertiesTableRecord>] Found records
      def find_all_unit_records_by_node_intf(node_name, intf_name)
        @records.find_all do |rec|
          rec.node == node_name && rec.interface =~ /#{intf_name}.\d+/
        end
      end
    end
  end
end
