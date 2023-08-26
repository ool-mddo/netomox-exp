# frozen_string_literal: true

require 'csv'

module NetomoxExp
  module TopologyBuilder
    module CSVMapper
      # Base class for csv-wrapper
      class TableBase
        # @!attribute [rw] records
        #   @return [Array]
        attr_accessor :records

        # @param [String] target Target network (config) data name
        # @param [String] table_file CSV File name
        def initialize(target, table_file)
          @orig_table = CSV.table("#{target}/#{table_file}")
          @records = []
        end
      end

      # Base class for record of csv-wrapper
      class TableRecordBase
        # get multiple method-results
        # @param [Array<String>] attrs Record columns (attribute method name)
        # @return [Array] Values of attrs
        def values(attrs)
          attrs.map { |attr| send(attr) }
        end

        protected

        # @param [String] value String value (boolean, "True, False" like string)
        # @return [Boolean] converted boolean value
        def true_string?(value)
          value.downcase == 'true'
        end

        # rubocop:disable Security/Eval

        # @param [String] str Array string (like '["a","b","c"]')
        # @return [Array<String>] Array of values (like ["a", "b", "c"])
        # @raise [StandardError]
        def parse_array_string(str)
          return [] if str.nil? || str.empty?
          raise StandardError, "Not array style string: #{str}" unless /\[.*\]/.match?(str)

          eval(str)
        end
        # rubocop:enable Security/Eval

        # Convert interface list string to link-edge object.
        #   ( array of `node[interface]` format string to link-edge)
        # @param [String] interfaces_str Interface list string
        # @return [Array<EdgeBase>] Array of link-edge
        def extract_interfaces(interfaces_str)
          interfaces_str =~ /\[(.+)\]/
          content = Regexp.last_match(1)
          content.split(/,\s*/).map { |str| EdgeBase.new(str) }
        end
      end

      # Base class of edges-table endpoint
      class EdgeBase < TableRecordBase
        # @!attribute [rw] node
        #   @return [String]
        # @!attribute [rw] interface
        #   @return [String]
        attr_accessor :node, :interface

        # @param [String] node Node name
        # @param [String] interface Interface (term-point) name
        # @return [EdgeBAse] link-edge object
        def self.generate(node, interface)
          EdgeBase.new("#{node}[#{interface}]")
        end

        # @param [String] interface_str `node[interface]` format string
        def initialize(interface_str)
          super()
          interface_str =~ /(.+)\[(.+)\]/
          @node = Regexp.last_match(1)
          @interface = Regexp.last_match(2)
        end

        # @param [EdgeBase] other
        # @return [Boolean] ture if equal
        def ==(other)
          @node == other.node && @interface == other.interface
        end

        # @return [String]
        def to_s
          "#{@node}[#{@interface}]"
        end
      end
    end
  end
end
