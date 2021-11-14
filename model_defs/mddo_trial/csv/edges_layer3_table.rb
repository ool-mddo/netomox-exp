# frozen_string_literal: true

require 'forwardable'
require_relative 'table_base'

# endpoint of layer3-edge
class EdgeLayer3 < EdgeBase
  # @!attribute [rw] ips
  #   @return [Array<String>]
  attr_accessor :ips

  # rubocop:disable Security/Eval
  # @param [String] interface_str `node[interface]` format string
  # @param [String] ips_str String of IP address list
  def initialize(interface_str, ips_str)
    super(interface_str)
    @ips = eval(ips_str) # string 2 array
  end
  # rubocop:enable Security/Eval

  # @return [String]
  def to_s
    "#{@node}[#{@interface}]#{@ips}"
  end

  # reverse function of #to_s
  # @param [String] interface_str `node[interface]` format string
  # @return [EdgeLayer3] layer3 link-edge
  def self.new_from_str(interface_str)
    interface_str =~ /(.+\[.+\])(.+)/
    EdgeLayer3.new(Regexp.last_match(1).to_s, Regexp.last_match(2).to_s)
  end
end

# row of layer3-edges table
class EdgesLayer3TableRecord < TableRecordBase
  # @!attribute [rw] src
  #   @return [EdgeLayer3]
  # @!attribute [rw] dst
  #   @return [EdgeLayer3]
  attr_accessor :src, :dst

  # @param [Enumerable] record A row of csv table (row)
  def initialize(record)
    super()
    @src = EdgeLayer3.new(record[:interface], record[:ips])
    @dst = EdgeLayer3.new(record[:remote_interface], record[:remote_ips])
  end
end

# llayer3-edges table
class EdgesLayer3Table < TableBase
  extend Forwardable

  def_delegators :@records, :each, :find, :[]

  # @param [String] target Target network (config) data name
  def initialize(target)
    super(target, 'edges_layer3.csv')
    @records = @orig_table.map { |r| EdgesLayer3TableRecord.new(r) }
  end
end
