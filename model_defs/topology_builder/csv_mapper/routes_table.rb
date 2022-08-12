# frozen_string_literal: true

require_relative 'table_base'

module TopologyBuilder
  module CSVMapper
    # row of routes table
    class RoutesTableRecord < TableRecordBase
      # @!attribute [rw] node
      #   @return [String]
      # @!attribute [rw] vrf
      #   @return [String]
      # @!attribute [rw] network
      #   @return [String]
      # @!attribute [rw] next_hop
      #   @return [String]
      # @!attribute [rw] next_hop_ip
      #   @return [String]
      # @!attribute [rw] next_hop_interface
      #   @return [String]
      # @!attribute [rw] protocol
      #   @return [String]
      # @!attribute [rw] metric
      #   @return [Integer]
      # @!attribute [rw] admin_distance
      #   @return [Integer]
      attr_accessor :node, :vrf, :network, :next_hop, :next_hop_ip, :next_hop_interface,
                    :protocol, :metric, :admin_distance

      # @param [Enumerable] record A row of csv_mapper table
      def initialize(record)
        super()
        @node = record[:node]
        @vrf = record[:vrf]
        @network = record[:network]
        @next_hop = record[:next_hop]
        @next_hop_ip = record[:next_hop_ip]
        @next_hop_interface = record[:next_hop_interface]
        @protocol = record[:protocol]
        @metric = record[:metric]
        @admin_distance = record[:admin_distance]
      end

      # @param [String] protocol Protocol name
      # @return [Boolean]
      def protocol?(protocol)
        @protocol == protocol.downcase
      end
    end

    # routes table
    class RoutesTable < TableBase
      # @param [String] target Target network (config) data name
      def initialize(target)
        super(target, 'routes.csv')
        @records = @orig_table.map { |r| RoutesTableRecord.new(r) }
      end

      # @param [String] node_name Node name to find
      # @return [Array<RoutesTableRecord>] Found records
      def find_all_records_by_node(node_name)
        @records.find_all { |r| r.node == node_name }
      end

      # @param [String] node_name Node name to find
      # @param [String] proto_name Protocol name to find
      # @return [Array<RoutesTableRecord>] Found records
      def find_all_records_by_node_proto(node_name, proto_name)
        find_all_records_by_node(node_name).find_all { |r| r.protocol?(proto_name)}
      end
    end
  end
end
