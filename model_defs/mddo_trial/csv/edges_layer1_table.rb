# frozen_string_literal: true

require 'forwardable'
require_relative 'table_base'

# row of layer1-edges table
class EdgesLayer1TableRecord < TableRecordBase
  # @!attribute [rw] src
  #   @return [EdgeBase]
  # @!attribute [rw] dst
  #   @return [EdgeBase]
  attr_accessor :src, :dst

  # @param [Enumerable] record A row of csv table (row)
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
end

# layer1-edges table
class EdgesLayer1Table < TableBase
  extend Forwardable

  def_delegators :@records, :each, :find, :[]

  # @param [String] target Target network (config) data name
  def initialize(target)
    super(target, 'edges_layer1.csv')
    @records = @orig_table.map { |r| EdgesLayer1TableRecord.new(r) }
  end

  # @param [PNode] node_name Node name
  # @param [String] interface_name Interface name
  # @return [nil, EdgeBase] Destination link-edge connected with the node/interface, or nil if not found
  def find_pair(node_name, interface_name)
    find_target = EdgeBase.new("#{node_name}[#{interface_name}]")
    rec = @records.find { |r| r.src == find_target }
    rec ? rec.dst : rec
  end
end
