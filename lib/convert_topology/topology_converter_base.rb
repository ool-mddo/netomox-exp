# frozen_string_literal: true

require 'json'
require 'netomox'

module NetomoxExp
  # base class of topology converter
  class TopologyConverterBase
    # @param [String] topology_data Topology data
    # @param [String] src_network Source network name (input of converter)
    # @param [Hash] options Other options
    # @raise [StandardError]
    def initialize(topology_data, src_network, options = {})
      @networks = Netomox::Topology::Networks.new(topology_data)
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

    # @param [String] node_name Node name (unsafe...include '/')
    # @return [String] Safe node name
    def safe_node_name(node_name)
      node_name.tr('/', '-')
    end
  end
end
