# frozen_string_literal: true

require 'netomox'

# rubocop:disable Metrics/MethodLength
def register_bgp_external(nws)
  nws.register do
    network 'bgp_external' do
      type Netomox::NWTYPE_MDDO_BGP
      support 'layer3_external'

      # AS65550, PNI
      node 'PNI01' do # TODO: Hostname must be Router-ID in bgp layer
        term_point 'peer_172.16.0.6' do
          support %w[layer3_external PNI01 Ethernet1]
        end
        term_point 'peer_172.16.1.10' do
          support %w[layer3_external PNI01 Ethernet1]
        end
      end

      # AS65520, POI-East
      node 'POI-East' do
        term_point 'peer_192.168.0.9' do
          support %w[layer3_external POI-East Ethernet1]
        end
        term_point 'peer_192.168.0.13' do
          support %w[layer3_external POI-East Ethernet2]
        end
      end
    end
  end
end
# rubocop:enable Metrics/MethodLength
