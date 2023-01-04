# frozen_string_literal: true

require_relative 'table_base'

module TopologyBuilder
  module CSVMapper
    # row of layer1-edges table
    class EdgesLayer1TableRecord < TableRecordBase
      # @!attribute [rw] src
      #   @return [EdgeBase]
      # @!attribute [rw] dst
      #   @return [EdgeBase]
      attr_accessor :src, :dst

      # @param [Enumerable] record A row of csv_mapper table
      def initialize(record)
        super()
        @src = EdgeBase.new(record[:interface])
        @dst = EdgeBase.new(record[:remote_interface])
      end

      # @param [EdgesLayer1TableRecord] other
      # @return [Boolean] true if src/dst are same in each record.
      def ==(other)
        @src == other.src && @dst == other.dst
      end

      # @return [String]
      def to_s
        "EdgesLayer1TableRecord: #{@src}->#{@dst}"
      end
    end

    # layer1-edges table
    class EdgesLayer1Table < TableBase
      # @param [String] target Target network (config) data name
      def initialize(target)
        super(target, 'edges_layer1.csv')
        @records = @orig_table.map { |r| EdgesLayer1TableRecord.new(r) }
      end

      # @param [String] node_name Source node name
      # @param [String] intf_name Source interface name
      # @return [nil, EdgesLayer1TableRecord] Record if found or nil if not found
      def find_link_by_src_node_intf(node_name, intf_name)
        edge = EdgeBase.new("#{node_name}[#{intf_name}]")
        @records.find { |r| r.src == edge }
      end

      # @param [String] node_name Node name
      # @param [String] interface_name Interface name
      # @return [nil, EdgeBase] Destination link-edge connected with the node/interface, or nil if not found
      def find_pair(node_name, interface_name)
        rec = find_link_by_src_node_intf(node_name, interface_name)
        rec&.dst
      end
    end
  end
end
