# frozen_string_literal: true

require_relative 'table_base'

module TopologyBuilder
  module CSVMapper
    # row of node-properties table
    class NodePropsTableRecord < TableRecordBase
      # @!attribute [rw] node
      #   @return [String]
      # @!attribute [rw] config_format
      #   @return [String]
      attr_accessor :node, :config_format

      # @param [Enumerable] record A row of csv_mapper table
      def initialize(record)
        super()
        @node = record[:node]
        @config_format = record[:configuration_format]
      end
    end

    # node-properties table
    class NodePropsTable < TableBase
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
  end
end
