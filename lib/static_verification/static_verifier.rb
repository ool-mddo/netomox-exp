# frozen_string_literal: true

require 'netomox'
require_relative 'layer1_verifier'
require_relative 'layer2_verifier'
require_relative 'layer3_verifier'
require_relative 'ospf_area_verifier'
require_relative 'bgp_proc_verifier'
require_relative 'bgp_as_verifier'

module NetomoxExp
  # static verification functions
  module StaticVerifier
    module_function

    # rubocop:disable Metrics/MethodLength

    # @param [Netomox::Topology::Network] network Network layer
    # @return [Class] Verifier class
    # @raise [StandardError] if network-type of the network is unknown
    def verifier_by_network_type(network)
      network_type = network.network_types.keys[0]
      case network_type
      when Netomox::NWTYPE_MDDO_L1
        Layer1Verifier
      when Netomox::NWTYPE_MDDO_L2
        Layer2Verifier
      when Netomox::NWTYPE_MDDO_L3
        Layer3Verifier
      when Netomox::NWTYPE_MDDO_OSPF_AREA
        OspfAreaVerifier
      when Netomox::NWTYPE_MDDO_BGP_PROC
        BgpProcVerifier
      when Netomox::NWTYPE_MDDO_BGP_AS
        BgpAsVerifier
      else
        raise StandardError, "Unknown network type:#{network_type}"
      end
    end
    # rubocop:enable Metrics/MethodLength
  end
end
