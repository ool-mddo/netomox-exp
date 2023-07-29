# frozen_string_literal: true

require 'netomox'

# rubocop:disable Metrics/MethodLength, Metrics/BlockLength, Metrics/AbcSize
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
        term_point 'peer_172.16.0.13' do
          support %w[layer3_external PNI01 Ethernet2]
        end
        term_point 'peer_172.26.1.2' do
          support %w[layer3_external PNI01 Ethernet3]
        end
      end
      node 'PNI02' do
        term_point 'peer_172.16.1.10' do
          support %w[layer3_external PNI02 Ethernet1]
        end
        term_point 'peer_172.16.1.13' do
          support %w[layer3_external PNI02 Ethernet2]
        end
        term_point 'peer_172.26.1.1' do
          support %w[layer3_external PNI02 Ethernet3]
        end
      end
      node 'PNI-Root' do
        term_point 'peer_172.16.0.14' do
          support %w[layer3_external PNI-Root Ethernet1]
        end
        term_point 'peer_172.16.0.14' do
          support %w[layer3_external PNI-Root Ethernet2]
        end
      end

      bdlink %w[PNI01 peer_172.26.1.2 PNI02 peer_172.26.1.1]

      bdlink %w[PNI01 peer_172.16.0.13 PNI-Root peer_172.16.0.14]
      bdlink %w[PNI02 peer_172.16.1.13 PNI-Root peer_172.16.0.14]

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
# rubocop:enable Metrics/MethodLength, Metrics/BlockLength, Metrics/AbcSize
