# frozen_string_literal: true

require 'forwardable'
require_relative 'p_networks'

# base class for data builder with pseudo networks
class DataBuilderBase
  attr_accessor :networks

  def initialize
    @networks = PNetworks.new # PNetworks
  end

  # @return [Netomox::DSL::Networks]
  def interpret
    @networks.interpret
  end

  # @return [Hash] RFC8345-structured hash object
  def topo_data
    interpret.topo_data
  end

  # print to stdout
  def dump
    @networks.dump
  end
end
