# frozen_string_literal: true

require 'netomox'

module NetomoxExp
  # layer1 interface description operations base
  class InterfaceDescrOpsBase
    # @param [Netomox::Topology::Networks] networks Networks object
    # @param [String] layer Layer name to handle
    def initialize(networks, layer)
      network = networks.find_network(layer)

      raise StandardError, "Layer:#{layer} is not found" if network.nil?
      unless network.attribute.is_a?(Netomox::Topology::MddoL1NetworkAttribute)
        raise StandardError, "Layer:#{layer} is not layer1"
      end

      @l1_nw = network
    end
  end
end
