# frozen_string_literal: true

require 'json'
require 'netomox'

module NetomoxExp
  # base class of topology converter
  class TopologyConverterBase
    # @param [String] topology_data Topology data
    # @param [String] src_network Source network name (input of converter)
    # @param [NamespaceConverter] ns_converter Namespace converter
    # @param [Hash] options Other options
    # @option options [String] :env_name Environment name (for cLab)
    # @option options [String] :bind_license Bind configs to add license key (for cLab/cRPD)
    # @raise [StandardError]
    def initialize(topology_data, src_network, ns_converter, options = {})
      @networks = Netomox::Topology::Networks.new(topology_data)
      @ns_converter = ns_converter
      @src_network = @networks.find_network(src_network)
      raise StandardError, "Network #{src_network} is not found in #{file} data" unless @src_network

      @options = options
    end

    # @return [Hash]
    def convert
      # abstract method
      {}
    end

    protected

    # @param [String] node_name Node name to convert (emulated L3-model name)
    # @return [String] Converted node name (emulated L1-agent name)
    def converted_node_l1agent(node_name)
      converted_node(node_name, 'l1_agent')
    end

    # @param [String] node_name Node name to convert (emulated L3-model name)
    # @return [String] Converted node name (emulated L1-principal name)
    def converted_node_l1principal(node_name)
      converted_node(node_name, 'l1_principal')
    end

    # @param [String] node_name Node name to convert (emulated L3-model name)
    # @param [String] tp_name Term-point name to convert (emulated L3-model name)
    # @return [String] Converted term-point name (emulated L1-agent name)
    def converted_tp_l1agent(node_name, tp_name)
      converted_tp(node_name, tp_name, 'l1_agent')
    end

    # @param [String] node_name Node name to convert (emulated L3-model name)
    # @param [String] tp_name Term-point name to convert (emulated L3-model name)
    # @return [String] Converted term-point name (emulated L1-principal name)
    def converted_tp_l1principal(node_name, tp_name)
      converted_tp(node_name, tp_name, 'l1_principal')
    end

    private

    # @param [String] node_name Node name to convert (emulated L3-model name)
    # @param [String] type name type (l1_principal or l1_agent)
    # @return [String] Converted node name (emulated L1-principal/agent name)
    def converted_node(node_name, type)
      @ns_converter.node_name_table.find_l1_alias(node_name)[type]
    end

    # @param [String] node_name Node name to convert (emulated L3-model name)
    # @param [String] tp_name Term-point name to convert (emulated L3-model name)
    # @param [String] type name type (l1_principal or l1_agent)
    # @return [String] Converted term-point name (emulated L1-principal/agent name)
    def converted_tp(node_name, tp_name, type)
      @ns_converter.tp_name_table.find_l1_alias(node_name, tp_name)[type]
    end
  end
end
