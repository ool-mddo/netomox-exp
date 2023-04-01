# frozen_string_literal: true

require_relative 'table_base'
require 'json'

module NetomoxExp
  module TopologyBuilder
    module CSVMapper
      # row of named-structure table
      class NamedStructuresTableRecord < TableRecordBase
        # @!attribute [rw] node
        #   @return [String]
        # @!attribute [rw] structure_type
        #   @return [String]
        # @!attribute [rw] structure_name
        #   @return [String]
        # @!attribute [rw] structure_definition
        #   @return [String]
        attr_accessor :node, :structure_type, :structure_name, :structure_definition

        # @param [Enumerable] record A row of csv_mapper table
        def initialize(record)
          super()
          @node = record[:node]
          @structure_type = record[:structure_type]
          @structure_name = record[:structure_name]
          @structure_definition = record[:structure_definition]
        end

        # @return [Array<String>] ospf redistribute protocols
        # @raise [StandardError]
        def ospf_redistribute_protocols
          # replace quotes to convert "json" format string
          definition = JSON.parse(@structure_definition.gsub(/"/, '\"').gsub(/'/, '"'))
          return [] unless definition

          protocols = definition['statements']
                      .filter { |s| s['class'] == 'org.batfish.datamodel.routing_policy.statement.If' }
                      .map { |s| extract_protocols_in_statement(s) }
          protocols.reject(&:empty?).flatten
        end

        private

        # @param [Hash] statement Statement of ospf-redistributed policy (Batfish parsed data)
        # @return [Array<String>] protocols
        def extract_protocols_in_statement(statement)
          guard = statement['guard']
          case guard['class']
          when 'org.batfish.datamodel.routing_policy.expr.MatchProtocol'
            guard['protocols']
          when 'org.batfish.datamodel.routing_policy.expr.Disjunction'
            guard['disjuncts'].map { |d| d['protocols'] }.flatten
          else
            []
          end
        end
      end

      # named-structure table
      class NamedStructuresTable < TableBase
        # @param [String] target Target network (config) data name
        def initialize(target)
          super(target, 'named_structures.csv')
          @records = @orig_table.map { |r| NamedStructuresTableRecord.new(r) }
        end

        # @param [String] node_name Node name
        # @param [String] structure_name Structure name
        # @return [nil, NamedStructuresTableRecord] Record if found or nil if not found
        def find_record_by_node_structure(node_name, structure_name)
          @records.find { |r| r.node == node_name && r.structure_name == structure_name }
        end
      end
    end
  end
end
