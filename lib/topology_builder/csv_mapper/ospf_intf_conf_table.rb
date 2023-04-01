# frozen_string_literal: true

require_relative 'table_base'

module NetomoxExp
  module TopologyBuilder
    module CSVMapper
      # row of ospf interface configuration table
      class OspfInterfaceConfigurationTableRecord < TableRecordBase
        # @!attribute [rw] node
        #   @return [String]
        # @!attribute [rw] interface
        #   @return [String]
        # @!attribute [rw] vrf
        #   @return [String]
        # @!attribute [rw] process_id
        #   @return [String]
        # @!attribute [rw] ospf_area_name
        #   @return [String]
        # @!attribute [rw] ospf_cost
        #   @return [Integer]
        # @!attribute [rw] ospf_network_type
        #   @return [String]
        # @!attribute [rw] ospf_hello_interval
        #   @return [Integer]
        # @!attribute [rw] ospf_dead_interval
        #   @return [Integer]
        attr_accessor :node, :interface, :vrf, :process_id, :ospf_area_name, :ospf_cost,
                      :ospf_network_type, :ospf_hello_interval, :ospf_dead_interval

        # rubocop:disable Metrics/MethodLength, Metrics/AbcSize

        # @param [Enumerable] record A row of csv_mapper table
        def initialize(record)
          super()
          interface = EdgeBase.new(record[:interface])
          @node = interface.node
          @interface = interface.interface

          @vrf = record[:vrf]
          @process_id = record[:process_id]
          @ospf_area_name = record[:ospf_area_name]
          @ospf_enabled = record[:ospf_enabled]
          @ospf_passive = record[:ospf_passive]
          @ospf_cost = record[:ospf_cost]
          @ospf_network_type = record[:ospf_network_type]
          @ospf_hello_interval = record[:ospf_hello_interval]
          @ospf_dead_interval = record[:ospf_dead_interval]
        end
        # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

        # @return [String]
        def to_s
          [@node, @interface, @process_id, @ospf_area_name, @ospf_enabled].map(&:to_s).join(', ')
        end

        # @return [Boolean] true if ospf enabled and not passive
        def ospf_active?
          ospf_enabled? && !ospf_passive?
        end

        # @return [Boolean] true if ospf is enabled in the interface
        def ospf_enabled?
          true_string?(@ospf_enabled)
        end
        alias ospf_enabled ospf_enabled?

        # @return [Boolean] true if the interface is passive-interface
        def ospf_passive?
          true_string?(@ospf_passive)
        end
        alias ospf_passive ospf_passive?
      end

      # ospf interface configuration table
      class OspfInterfaceConfigurationTable < TableBase
        # @param [String] target Target network (configs) data name
        def initialize(target)
          super(target, 'ospf_intf_conf.csv')
          @records = @orig_table.map { |r| OspfInterfaceConfigurationTableRecord.new(r) }
        end

        # @param [String] node Node name to find
        # @param [String] intf interface name to find
        # @return [OspfInterfaceConfigurationTableRecord,nil] Found record
        def find_record_by_node_intf(node, intf)
          @records.find { |r| r.node == node && r.interface == intf }
        end
      end
    end
  end
end
