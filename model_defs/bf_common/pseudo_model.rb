# frozen_string_literal: true

require 'forwardable'
require_relative 'p_networks'

# base class for data builder with pseudo networks
class DataBuilderBase
  # @!attribute [rw] networks
  #   @return [PNetworks]
  attr_accessor :networks

  def initialize(debug: false)
    @networks = PNetworks.new # PNetworks
    @use_debug = debug
  end

  # @return [Netomox::DSL::Networks]
  def interpret
    @networks.interpret
  end

  # @return [Hash] RFC8345-structured hash object
  def topo_data
    interpret.topo_data
  end

  # print debug message to stderr
  # @param [Array] message Objects to debug print
  def debug_print(*message)
    warn 'DEBUG: ', message if @use_debug
  end

  # print to stdout
  def dump
    @networks.dump
  end
end
