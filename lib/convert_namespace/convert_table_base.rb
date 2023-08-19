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

    # @param [String] l3_model Layer3 model node/tp name
    # @param [String] l1_agent Layer1 config node/tp name
    # @param [String] l1_principal Layer1 instance node/tp name
    # @return [Hash] convert table entry
    def emulated_name_dict(l3_model, l1_agent: nil, l1_principal: nil)
      dict = { 'l3_model' => l3_model, 'l1_agent' => l3_model, 'l1_principal' => l3_model }
      dict['l1_agent'] = l1_agent unless l1_agent.nil?
      dict['l1_principal'] = l1_principal unless l1_principal.nil?
      dict
    end

    # @param [String] l3_model Layer3 model node/tp name
    # @return [Hash] convert table entry
    def pass_through_name_dict(l3_model)
      { 'l3_model' => l3_model, 'l1_agent' => '__pass__', 'l1_principal' => '__pass__' }
    end
  end
end
