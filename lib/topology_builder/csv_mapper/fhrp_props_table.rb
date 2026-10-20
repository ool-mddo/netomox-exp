# frozen_string_literal: true

require_relative 'table_base'

module NetomoxExp
  module TopologyBuilder
    module CSVMapper
      # row of FHRP (First Hop Redundancy Protocol: VRRP/HSRP) properties table
      class FhrpPropertiesTableRecord < TableRecordBase
        # @!attribute [rw] protocol
        #   @return [String] 'vrrp' or 'hsrp'
        # @!attribute [rw] node
        #   @return [String]
        # @!attribute [rw] interface
        #   @return [String]
        # @!attribute [rw] group_id
        #   @return [Integer]
        # @!attribute [rw] virtual_addresses
        #   @return [Array<String>]
        # @!attribute [rw] source_address
        #   @return [String]
        # @!attribute [rw] priority
        #   @return [Integer]
        attr_accessor :protocol, :node, :interface, :group_id, :virtual_addresses, :source_address, :priority

        # rubocop:disable Metrics/MethodLength

        # @param [String] protocol Protocol of the table ('vrrp' or 'hsrp')
        # @param [Enumerable] record A row of csv_mapper table
        def initialize(protocol, record)
          super()
          @protocol = protocol
          interface = EdgeBase.new(record[:interface])
          @node = interface.node
          @interface = interface.interface

          @group_id = record[:group_id].to_i
          @virtual_addresses = parse_array_string(record[:virtual_addresses])
          @source_address = record[:source_address]
          @priority = record[:priority].to_i
          @preempt = record[:preempt]
          @active = record[:active]
        end
        # rubocop:enable Metrics/MethodLength

        # @return [Boolean] true if preempt is enabled
        def preempt?
          true_string?(@preempt.to_s)
        end
        alias preempt preempt?

        # @return [Boolean] true if the group is active
        def active?
          true_string?(@active.to_s)
        end
        alias active active?

        # @return [Hash] Attribute data of layer3 term-point (an element of `fhrp` attribute)
        def to_attribute
          {
            protocol: @protocol, group_id: @group_id, virtual_addresses: @virtual_addresses, priority: @priority,
            preempt: preempt?, source_address: @source_address, active: active?
          }
        end

        # @return [String]
        def to_s
          [@protocol, @node, @interface, @group_id].join(', ')
        end
      end

      # FHRP (VRRP/HSRP) properties table
      #   vrrp_props.csv and hsrp_props.csv have the same format, this table contains both of them.
      #   A missing csv file is treated as an empty table (queries of old version don't have these files).
      class FhrpPropertiesTable
        # Protocol and its csv file name
        TABLE_FILES = { 'vrrp' => 'vrrp_props.csv', 'hsrp' => 'hsrp_props.csv' }.freeze

        # @!attribute [rw] records
        #   @return [Array<FhrpPropertiesTableRecord>]
        attr_accessor :records

        # @param [String] target Target network (config) data name
        def initialize(target)
          @records = TABLE_FILES.flat_map { |protocol, file| read_records(protocol, File.join(target, file)) }
        end

        # @param [String] node_name Node name
        # @param [String] intf_name Interface name
        # @return [Array<FhrpPropertiesTableRecord>] Found records, sorted by protocol and group id
        def find_all_records_by_node_intf(node_name, intf_name)
          @records
            .find_all { |r| r.node == node_name && r.interface == intf_name }
            .sort_by { |r| [r.protocol, r.group_id] }
        end

        private

        # @param [String] protocol Protocol ('vrrp' or 'hsrp')
        # @param [String] file_path CSV file path
        # @return [Array<FhrpPropertiesTableRecord>] Records (empty if the file doesn't exist)
        def read_records(protocol, file_path)
          unless File.exist?(file_path)
            NetomoxExp.logger.info "#{file_path} is not found. (treated as empty table)"
            return []
          end

          CSV.table(file_path).map { |r| FhrpPropertiesTableRecord.new(protocol, r) }
        end
      end
    end
  end
end
