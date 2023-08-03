# frozen_string_literal: true

require 'netomox'

# rubocop:disable Metrics/MethodLength, Metrics/BlockLength, Metrics/AbcSize
def register_layer3_external(nws)
  nws.register do
    network 'layer3_external' do
      type Netomox::NWTYPE_MDDO_L3

      # AS65550, PNI
      node 'PNI01' do
        term_point 'Ethernet1' do
          attribute({ ip_addrs: %w[172.16.0.5/30] })
        end
        term_point 'Ethernet2' do
          attribute({ ip_addrs: %w[172.16.1.9/30] })
        end

        term_point 'Ethernet3' do
          attribute({ ip_addrs: %w[10.0.1.1/24] })
        end
        term_point 'Ethernet4' do
          attribute({ ip_addrs: %w[10.0.2.1/24] })
        end
        term_point 'Ethernet5' do
          attribute({ ip_addrs: %w[10.0.3.1/24] })
        end
        term_point 'Ethernet6' do
          attribute({ ip_addrs: %w[10.0.4.1/24] })
        end
      end

      node 'endpoint01-iperf1' do
        term_point 'ens2' do
          attribute({ ip_addrs: %w[10.0.1.100/24] })
        end
      end
      node 'endpoint01-iperf2' do
        term_point 'ens3' do
          attribute({ ip_addrs: %w[10.0.2.100/24] })
        end
      end
      node 'endpoint01-iperf3' do
        term_point 'enp1s4' do
          attribute({ ip_addrs: %w[10.0.3.100/24] })
        end
      end
      node 'endpoint01-iperf4' do
        term_point 'enp1s5' do
          attribute({ ip_addrs: %w[10.0.4.100/24] })
        end
      end

      bdlink %w[PNI01 Ethernet3 endpoint01-iperf1 ens2]
      bdlink %w[PNI01 Ethernet4 endpoint01-iperf2 ens3]
      bdlink %w[PNI01 Ethernet5 endpoint01-iperf3 enp1s4]
      bdlink %w[PNI01 Ethernet6 endpoint01-iperf4 enp1s5]

      # AS65520, POI-East
      node 'POI-East' do
        term_point 'Ethernet1' do
          attribute({ ip_addrs: %w[192.168.0.10/30] })
        end
        term_point 'Ethernet2' do
          attribute({ ip_addrs: %w[192.168.0.14/30] })
        end
        term_point 'Ethernet3' do
          attribute({ ip_addrs: %w[10.100.0.1/24] })
        end
        term_point 'Ethernet4' do
          attribute({ ip_addrs: %w[10.110.0.1/24] })
        end
        term_point 'Ethernet5' do
          attribute({ ip_addrs: %w[10.120.0.1/24] })
        end
        term_point 'Ethernet6' do
          attribute({ ip_addrs: %w[10.130.0.1/24] })
        end
      end

      node 'endpoint02-iperf1' do
        term_point 'ens2' do
          attribute({ ip_addrs: %w[10.100.0.100/16] })
        end
      end
      node 'endpoint02-iperf2' do
        term_point 'ens3' do
          attribute({ ip_addrs: %w[10.110.0.100/20] })
        end
      end
      node 'endpoint02-iperf3' do
        term_point 'enp1s4' do
          attribute({ ip_addrs: %w[10.120.0.100/17] })
        end
      end
      node 'endpoint02-iperf4' do
        term_point 'enp1s5' do
          attribute({ ip_addrs: %w[10.130.0.100/21] })
        end
      end

      bdlink %w[POI-East Ethernet3 endpoint02-iperf1 ens2]
      bdlink %w[POI-East Ethernet4 endpoint02-iperf2 ens3]
      bdlink %w[POI-East Ethernet5 endpoint02-iperf3 enp1s4]
      bdlink %w[POI-East Ethernet6 endpoint02-iperf4 enp1s5]
    end
  end
end
# rubocop:enable Metrics/MethodLength, Metrics/BlockLength, Metrics/AbcSize
