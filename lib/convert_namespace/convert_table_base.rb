# frozen_string_literal: true

require 'forwardable'

module NetomoxExp
  # Base class of a convert table
  class ConvertTableBase
    extend Forwardable
    delegate %i(keys []) => :@convert_table

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

    # @param [String] l3_name Layer3 model node/tp name
    # @return [Hash] l3 node name dic contains specified l3 node
    def emulated_name_dict_short(l3_name)
      { 'l3' => l3_name, 'l1_agent' => l3_name, 'l1_principal' => l3_name }
    end

    # @param [String] l3_name Layer3 model node/tp name
    # @param [String] l1_agent_name Layer1 config node/tp name
    # @param [String] l1_principal_name Layer1 instance node/tp name
    def emulated_name_dict(l3_name, l1_agent_name, l1_principal_name)
      { 'l3' => l3_name, 'l1_agent' => l1_agent_name, 'l1_principal' => l1_principal_name }
    end
  end
end
