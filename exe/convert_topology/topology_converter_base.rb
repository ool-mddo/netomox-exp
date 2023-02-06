# frozen_string_literal: true

require 'json'
require 'netomox'

module TopologyOperator
  # base class of topology converter
  class TopologyConverterBase
    # @param [String] file Topology file base
    # @param [String] src_network Source network name (input of converter)
    # @param [Hash] options Other options
    # @raise [StandardError]
    def initialize(file, src_network, options = {})
      @networks = read_networks(file)
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

    private

    # @param [String] file Topology file path
    # @return [Netomox::Topology::Networks]
    def read_networks(file)
      raw_data = JSON.parse(File.read(file))
      Netomox::Topology::Networks.new(raw_data)
    end
  end
end
