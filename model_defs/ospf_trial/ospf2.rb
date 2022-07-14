# frozen_string_literal: true

require 'netomox'

# rubocop:disable Metrics/MethodLength, Metrics/BlockLength, Metrics/AbcSize
def register_ospf2(nws)
  nws.register do
    network 'ospf' do
      type Netomox::NWTYPE_MDDO_L3
      support 'ospf_trial_l3'

      node 'Seg_203.0.113.0/24' do
        support %w[ospf_trial_l3 Seg_203.0.113.0/24]
        term_point 'sw1_vlan_eth2' do
          support %w[ospf_trial_l3 Seg_203.0.113.0/24 sw1_vlan_eth2]
        end
      end
      node 'rt1' do
        support %w[ospf_trial_l3 rt1]
        term_point 'eth1' do
          support %w[ospf_trial_l3 rt1 eth1]
        end
        term_point 'eth2' do
          support %w[ospf_trial_l3 rt1 eth2]
        end
        term_point 'eth3' do
          support %w[ospf_trial_l3 rt1 eth2]
        end
      end
      node 'Seg_10.0.0.0/30' do
        support %w[ospf_trial_l3 Seg_10.0.0.0/30]
        term_point 'rt1_eth2' do
          support %w[ospf_trial_l3 Seg_10.0.0.0/30 rt1_eth2]
        end
        term_point 'rt2_eth1' do
          support %w[ospf_trial_l3 Seg_10.0.0.0/30 rt2_eth1]
        end
        term_point 'area100'
      end
      node 'Seg_10.0.1.0/30' do
        support %w[ospf_trial_l3 Seg_10.0.1.0/30]
        term_point 'rt1_eth3' do
          support %w[ospf_trial_l3 Seg_10.0.1.0/30 rt1_eth3]
        end
        term_point 'rt3_eth1' do
          support %w[ospf_trial_l3 Seg_10.0.1.0/30 rt3_eth1]
        end
        term_point 'area100'
      end
      node 'rt2' do
        support %w[ospf_trial_l3 rt2]
        term_point 'eth1' do
          support %w[ospf_trial_l3 rt2 eth1]
        end
        term_point 'eth2' do
          support %w[ospf_trial_l3 rt2 eth2]
        end
      end
      node 'rt3' do
        support %w[ospf_trial_l3 rt3]
        term_point 'eth1' do
          support %w[ospf_trial_l3 rt3 eth1]
        end
        term_point 'eth2' do
          support %w[ospf_trial_l3 rt3 eth2]
        end
      end
      node 'Seg_10.1.0.0/24' do
        support %w[ospf_trial_l3 Seg_10.1.0.0/24]
        term_point 'sw2_vlan_eth1' do
          support %w[ospf_trial_l3 Seg_10.1.0.0/24 sw2_vlan_eth1]
        end
        term_point 'sw2_vlan_eth2' do
          support %w[ospf_trial_l3 Seg_10.1.0.0/24 sw2_vlan_eth2]
        end
        term_point 'sw2_vlan_eth3' do
          support %w[ospf_trial_l3 Seg_10.1.0.0/24 sw2_vlan_eth3]
        end
        term_point 'area100'
      end
      node 'rt4' do
        support %w[ospf_trial_l3 rt4]
        term_point 'eth1' do
          support %w[ospf_trial_l3 rt4 eth1]
        end
        term_point 'eth2' do
          support %w[ospf_trial_l3 rt4 eth2]
        end
      end
      node 'Seg_192.168.0.0/24' do
        support %w[ospf_trial_l3 Seg_192.168.0.0/24]
        term_point 'sw3_vlan_eth1' do
          support %w[ospf_trial_l3 Seg_192.168.0.0/24 sw3_vlan_eth1]
        end
        term_point 'area100'
      end

      bdlink %w[Seg_203.0.113.0/24 sw1_vlan_eth2 rt1 eth1]

      bdlink %w[rt1 eth2 Seg_10.0.0.0/30 rt2_eth1]
      bdlink %w[Seg_10.0.0.0/30 rt1_eth2 rt2 eth1]

      bdlink %w[rt1 eth3 Seg_10.0.1.0/30 rt3_eth1]
      bdlink %w[Seg_10.0.1.0/30 rt1_eth3 rt3 eth1]

      bdlink %w[rt2 eth2 Seg_10.1.0.0/24 sw2_vlan_eth1]
      bdlink %w[rt3 eth2 Seg_10.1.0.0/24 sw2_vlan_eth2]
      bdlink %w[Seg_10.1.0.0/24 sw2_vlan_eth3 rt4 eth1]

      bdlink %w[rt4 eth2 Seg_192.168.0.0/24 sw3_vlan_eth1]

      node 'area100' do
        term_point '10.0.0.0/30'
        term_point '10.0.1.0/30'
        term_point '10.1.0.0/24'
        term_point '192.168.0.0/24'
      end
      bdlink %w[area100 10.0.0.0/30 Seg_10.0.0.0/30 area100]
      bdlink %w[area100 10.0.1.0/30 Seg_10.0.1.0/30 area100]
      bdlink %w[area100 10.1.0.0/24 Seg_10.1.0.0/24 area100]
      bdlink %w[area100 192.168.0.0/24 Seg_192.168.0.0/24 area100]
    end
  end
end
# rubocop:enable Metrics/MethodLength, Metrics/BlockLength, Metrics/AbcSize
