# frozen_string_literal: true

require 'netomox'

# rubocop:disable Metrics/MethodLength, Metrics/BlockLength, Metrics/AbcSize
def register_layer2(nws)
  nws.register do
    network 'ospf_trial_l2' do
      type Netomox::NWTYPE_MDDO_L2
      support 'ospf_trial_l1'

      node 'svr1_eth1' do
        support %w[ospf_trial_l1 svr1]
        term_point 'eth1' do
          support %w[ospf_trial_l1 svr1 eth1]
        end
      end
      node 'sw1_vlan' do
        support %w[ospf_trial_l1 sw1]
        term_point 'eth1' do
          support %w[ospf_trial_l1 sw1 eth1]
        end
        term_point 'eth2' do
          support %w[ospf_trial_l1 sw1 eth2]
        end
      end
      node 'rt1_eth1' do
        support %w[ospf_trial_l1 rt1]
        term_point 'eth1' do
          support %w[ospf_trial_l1 rt1 eth1]
        end
      end
      bdlink %w[svr1_eth1 eth1 sw1_vlan eth1]
      bdlink %w[sw1_vlan eth2 rt1_eth1 eth1]

      node 'rt1_eth2' do
        support %w[ospf_trial_l1 rt1]
        term_point 'eth2' do
          support %w[ospf_trial_l1 rt1 eth2]
        end
      end
      node 'rt2_eth1' do
        support %w[ospf_trial_l1 rt2]
        term_point 'eth1' do
          support %w[ospf_trial_l1 rt2 eth1]
        end
      end
      bdlink %w[rt1_eth2 eth2 rt2_eth1 eth1]

      node 'rt1_eth3' do
        support %w[ospf_trial_l1 rt1]
        term_point 'eth3' do
          support %w[ospf_trial_l1 rt1 eth3]
        end
      end
      node 'rt3_eth1' do
        support %w[ospf_trial_l1 rt3]
        term_point 'eth1' do
          support %w[ospf_trial_l1 rt3 eth1]
        end
      end
      bdlink %w[rt1_eth3 eth3 rt3_eth1 eth1]

      node 'rt2_eth2' do
        support %w[ospf_trial_l1 rt2]
        term_point 'eth2' do
          support %w[ospf_trial_l1 rt2 eth2]
        end
      end
      node 'rt3_eth2' do
        support %w[ospf_trial_l1 rt3]
        term_point 'eth2' do
          support %w[ospf_trial_l1 rt3 eth2]
        end
      end
      node 'sw2_vlan' do
        support %w[ospf_trial_l1 sw2]
        term_point 'eth1' do
          support %w[ospf_trial_l1 sw2 eth1]
        end
        term_point 'eth2' do
          support %w[ospf_trial_l1 sw2 eth2]
        end
        term_point 'eth3' do
          support %w[ospf_trial_l1 sw2 eth3]
        end
      end
      node 'rt4_eth1' do
        support %w[ospf_trial_l1 rt4]
        term_point 'eth1' do
          support %w[ospf_trial_l1 rt4 eth1]
        end
      end
      bdlink %w[rt2_eth2 eth2 sw2_vlan eth1]
      bdlink %w[rt3_eth2 eth2 sw2_vlan eth2]
      bdlink %w[sw2_vlan eth3 rt4_eth1 eth1]

      node 'rt4_eth2' do
        support %w[ospf_trial_l1 rt4]
        term_point 'eth2' do
          support %w[ospf_trial_l1 rt4 eth2]
        end
      end
      node 'sw3_vlan' do
        support %w[ospf_trial_l1 sw2]
        term_point 'eth1' do
          support %w[ospf_trial_l1 sw2 eth1]
        end
        term_point 'eth2' do
          support %w[ospf_trial_l1 sw2 eth2]
        end
      end
      node 'svr2_eth1' do
        support %w[ospf_trial_l1 svr2]
        term_point 'eth1' do
          support %w[ospf_trial_l1 svr2 eth1]
        end
      end
      bdlink %w[rt4_eth2 eth2 sw3_vlan eth1]
      bdlink %w[sw3_vlan eth2 svr2_eth1 eth1]
    end
  end
end
# rubocop:enable Metrics/MethodLength, Metrics/BlockLength, Metrics/AbcSize
