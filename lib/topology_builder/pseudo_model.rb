# frozen_string_literal: true

require 'forwardable'
require 'netomox'

module NetomoxExp
  module TopologyBuilder
    # base class for data builder with pseudo networks
    class DataBuilderBase
      # @!attribute [rw] networks
      #   @return [Netomox::PseudoDSL::PNetworks]
      attr_accessor :networks

      # @param [Boolean] debug Debug mode (true if enable, default = false)
      def initialize(debug: false)
        @networks = Netomox::PseudoDSL::PNetworks.new # PNetworks
        @use_debug = debug
        @logger = NetomoxExp.logger
        debug_print "# DEBUG MODE: #{@use_debug}"
      end

      # @return [Netomox::DSL::Networks]
      def interpret
        @networks.interpret
      end

      # @return [Hash] RFC8345-structured hash object
      def topo_data
        interpret.topo_data
      end

      # print data to stderr
      # @return [void]
      def dump
        @networks.dump
      end

      protected

      # print debug message to stderr
      # @param [Array] message Objects to debug print
      # @return [void]
      def debug_print(*message)
        warn message if @use_debug
      end
    end
  end
end
