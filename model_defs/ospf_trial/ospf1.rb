# frozen_string_literal: true

require 'netomox'

# rubocop:disable Metrics/MethodLength, Metrics/BlockLength, Metrics/AbcSize
def register_ospf1(nws)
  # rfc8346 ospf-extend based
  nws.register do
    network 'ospf_area0' do
      type Netomox::NWTYPE_MDDO_OSPF_AREA
      support 'ospf_trial_l3'
      attribute({ identifier: '0.0.0.0' })

      node 'rt1' do
        support %w[ospf_trial_l3 rt1]
        attr = {
          node_type: 'ospf_proc',
          router_id: '172.16.0.1',
          log_adjacency_change: true,
          redistribute: [
            { protocol: 'connected' },
            { protocol: 'static' }
          ]
        }
        attribute(attr)
        term_point 'eth2' do
          support %w[ospf_trial_l3 rt1 eth2]
          attr = {
            metric: 10,
            neighbors: [{ router_id: '172.16.0.2', ip_addr: '10.0.0.2' }]
          }
          attribute(attr)
        end
        term_point 'eth3' do
          support %w[ospf_trial_l3 rt1 eth2]
          attr = {
            metric: 20,
            neighbors: [{ router_id: '172.16.0.3', ip_addr: '10.0.1.2' }]
          }
          attribute(attr)
        end
      end
      node 'Seg_10.0.0.0/30' do
        support %w[ospf_trial_l3 Seg_10.0.0.0/30]
        attribute({ node_type: 'segment' })
        term_point 'rt1_eth2' do
          support %w[ospf_trial_l3 Seg_10.0.0.0/30 rt1_eth2]
        end
        term_point 'rt2_eth1' do
          support %w[ospf_trial_l3 Seg_10.0.0.0/30 rt2_eth1]
          attribute({ priority: 1 })
        end
      end
      node 'Seg_10.0.1.0/30' do
        support %w[ospf_trial_l3 Seg_10.0.1.0/30]
        attribute({ node_type: 'segment' })
        term_point 'rt1_eth3' do
          support %w[ospf_trial_l3 Seg_10.0.1.0/30 rt1_eth3]
        end
        term_point 'rt3_eth1' do
          support %w[ospf_trial_l3 Seg_10.0.1.0/30 rt3_eth1]
          attribute({ priority: 10 })
        end
      end
      node 'rt2' do
        support %w[ospf_trial_l3 rt2]
        attr = {
          node_type: 'ospf_proc',
          router_id: '172.16.0.2',
          log_adjacency_change: true,
          redistribute: [{ protocol: 'connected' }]
        }
        attribute(attr)
        term_point 'eth1' do
          support %w[ospf_trial_l3 rt2 eth1]
        end
        term_point 'eth2' do
          support %w[ospf_trial_l3 rt2 eth2]
        end
      end
      node 'rt3' do
        support %w[ospf_trial_l3 rt3]
        attr = {
          node_type: 'ospf_proc',
          router_id: '172.16.0.3',
          log_adjacency_change: true,
          redistribute: [{ protocol: 'connected' }]
        }
        attribute(attr)
        term_point 'eth1' do
          support %w[ospf_trial_l3 rt3 eth1]
        end
        term_point 'eth2' do
          support %w[ospf_trial_l3 rt3 eth2]
        end
      end
      node 'Seg_10.1.0.0/24' do
        support %w[ospf_trial_l3 Seg_10.1.0.0/24]
        attribute({ node_type: 'segment' })
        term_point 'sw2_vlan_eth1' do
          support %w[ospf_trial_l3 Seg_10.1.0.0/24 sw2_vlan_eth1]
        end
        term_point 'sw2_vlan_eth2' do
          support %w[ospf_trial_l3 Seg_10.1.0.0/24 sw2_vlan_eth2]
        end
        term_point 'sw2_vlan_eth3' do
          support %w[ospf_trial_l3 Seg_10.1.0.0/24 sw2_vlan_eth3]
        end
      end
      node 'rt4' do
        support %w[ospf_trial_l3 rt4]
        attr = {
          node_type: 'ospf_proc',
          router_id: '172.16.0.4',
          log_adjacency_change: true,
          redistribute: [{ protocol: 'connected' }]
        }
        attribute(attr)
        term_point 'eth1' do
          support %w[ospf_trial_l3 rt4 eth1]
          attribute({ priority: 0 })
        end
        term_point 'eth2' do
          support %w[ospf_trial_l3 rt4 eth2]
        end
      end
      node 'Seg_192.168.0.0/24' do
        support %w[ospf_trial_l3 Seg_192.168.0.0/24]
        attribute({ node_type: 'segment' })
        term_point 'sw3_vlan_eth1' do
          support %w[ospf_trial_l3 Seg_192.168.0.0/24 sw3_vlan_eth1]
          attribute({ passive: true })
        end
      end

      bdlink %w[rt1 eth2 Seg_10.0.0.0/30 rt2_eth1]
      bdlink %w[Seg_10.0.0.0/30 rt1_eth2 rt2 eth1]

      bdlink %w[rt1 eth3 Seg_10.0.1.0/30 rt3_eth1]
      bdlink %w[Seg_10.0.1.0/30 rt1_eth3 rt3 eth1]

      bdlink %w[rt2 eth2 Seg_10.1.0.0/24 sw2_vlan_eth1]
      bdlink %w[rt3 eth2 Seg_10.1.0.0/24 sw2_vlan_eth2]
      bdlink %w[Seg_10.1.0.0/24 sw2_vlan_eth3 rt4 eth1]

      bdlink %w[rt4 eth2 Seg_192.168.0.0/24 sw3_vlan_eth1]
    end
  end
end
# rubocop:enable Metrics/MethodLength, Metrics/BlockLength, Metrics/AbcSize
