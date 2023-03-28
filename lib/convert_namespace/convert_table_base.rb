# frozen_string_literal: true

module NetomoxExp
  # Base class of a convert table
  class ConvertTableBase
    def initialize
      @convert_table = {}
      @src_nws = nil # initialized in #make_table
    end

    # @return [Hash] convert table
    def to_data
      @convert_table
    end

    # @param [Netomox::Topology::Networks] src_nws Source networks
    # @return [void]
    def make_table(src_nws)
      @src_nws = src_nws
    end

    # @param [Hash] table_data Convert table
    # @return [void]
    def load_table(table_data)
      @convert_table = table_data
    end

    protected

    # @param [Netomox::Topology::Node] node
    def segment_node?(node)
      node.attribute.node_type == 'segment'
    end

    # @param [Netomox::Topology::TermPoint] term_point Term-point (L3)
    # @return [Boolean] True if the tp name is loopback
    def loopback?(term_point)
      !term_point.attribute.empty? && term_point.attribute.flags.include?('loopback')
    end
  end
end
