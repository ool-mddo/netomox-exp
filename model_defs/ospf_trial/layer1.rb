# frozen_string_literal: true

require 'netomox'

# rubocop:disable Metrics/MethodLength, Metrics/BlockLength, Metrics/AbcSize
def register_layer1(nws)
  nws.register do
    network 'ospf_trial_l1' do
      type Netomox::NWTYPE_MDDO_L1

      node 'svr1' do
        term_point 'eth1'
      end
      node 'sw1' do
        term_point 'eth1'
        term_point 'eth2'
      end
      node 'rt1' do
        term_point 'eth1'
        term_point 'eth2'
        term_point 'eth3'
      end
      node 'rt2' do
        term_point 'eth1'
        term_point 'eth2'
      end
      node 'rt3' do
        term_point 'eth1'
        term_point 'eth2'
      end
      node 'sw2' do
        term_point 'eth1'
        term_point 'eth2'
        term_point 'eth3'
      end
      node 'rt4' do
        term_point 'eth1'
        term_point 'eth2'
      end
      node 'sw3' do
        term_point 'eth1'
        term_point 'eth2'
      end
      node 'svr2' do
        term_point 'eth1'
      end

      bdlink %w[svr1 eth1 sw1 eth1]
      bdlink %w[sw1 eth2 rt1 eth1]
      bdlink %w[sw1 eth2 rt1 eth1]
      bdlink %w[rt1 eth2 rt2 eth1]
      bdlink %w[rt1 eth3 rt3 eth1]
      bdlink %w[rt2 eth2 sw2 eth1]
      bdlink %w[rt3 eth2 sw2 eth2]
      bdlink %w[sw2 eth3 rt4 eth1]
      bdlink %w[rt4 eth2 sw3 eth1]
      bdlink %w[sw3 eth2 svr2 eth1]
    end
  end
end
# rubocop:enable Metrics/MethodLength, Metrics/BlockLength, Metrics/AbcSize
