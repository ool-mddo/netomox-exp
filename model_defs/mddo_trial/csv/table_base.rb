# frozen_string_literal: true

require 'csv'

# Base class for csv-wrapper
class TableBase
  # @!attribute [rw] records
  #   @return [Array]
  attr_accessor :records

  # @param [String] target Target network (config) data name
  # @param [String] table_file CSV File name
  def initialize(target, table_file)
    csv_dir = "model_defs/mddo_trial/csv/#{target}"
    @orig_table = CSV.table("#{csv_dir}/#{table_file}")
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
