# frozen_string_literal: true

require 'netomox'

# rubocop:disable Metrics/MethodLength, Metrics/AbcSize
def register_target_layer3(nws)
  nws.register do
    network 'layer3' do
      support 'layer1'
      support 'layer2'

      # RegionA Nodes
      node 'RegionA-PE01-GRT' do
        (0..3).each { |i| term_point "p#{i}" }
        support %w[layer1 RegionA-PE01]
      end
      node 'RegionA-PE02-GRT' do
        (0..3).each { |i| term_point "p#{i}" }
        support %w[layer1 RegionA-PE02]
      end

      node 'RegionA-CE01-GRT' do
        (0..5).each { |i| term_point "p#{i}" }
        support %w[layer2 RegionA-CE01-GRT]
      end
      node 'RegionA-CE01-VRF' do
        (4..5).each { |i| term_point "p#{i}" }
        support %w[layer2 RegionA-CE01-VRF]
      end
      node 'RegionA-CE02-GRT' do
        (0..5).each { |i| term_point "p#{i}" }
        support %w[layer2 RegionA-CE02-GRT]
      end
      node 'RegionA-CE02-VRF' do
        (4..5).each { |i| term_point "p#{i}" }
        support %w[layer2 RegionA-CE02-VRF]
      end

      node 'RegionA-VL10' do
        (0..3).each { |i| term_point "p#{i}" }
        support %w[layer2 RegionA-CE01-VL10]
        support %w[layer2 RegionA-CE02-VL10]
        support %w[layer2 RegionA-Acc01-VL10]
      end
      node 'RegionA-VL20' do
        (0..1).each { |i| term_point "p#{i}" }
        support %w[layer2 RegionA-CE01-VL20]
        support %w[layer2 RegionA-CE02-VL20]
      end
      node 'RegionA-VL110' do
        (0..3).each { |i| term_point "p#{i}" }
        support %w[layer2 RegionA-CE01-VL110]
        support %w[layer2 RegionA-CE02-VL110]
        support %w[layer2 RegionA-Acc01-VL110]
      end
      node 'RegionA-VL120' do
        (0..1).each { |i| term_point "p#{i}" }
        support %w[layer2 RegionA-CE01-VL120]
        support %w[layer2 RegionA-CE02-VL120]
      end

      node 'RegionA-Svr01' do
        (0..1).each { |i| term_point "eno#{i}" }
        support %w[layer2 RegionA-Svr01]
      end
      node 'RegionA-Svr02' do
        (0..1).each { |i| term_point "eno#{i}" }
        support %w[layer2 RegionA-Svr02]
      end

      # RegionA Links
      bdlink %w[RegionA-PE01-GRT p0 RegionA-PE02-GRT p0]
      bdlink %w[RegionA-PE01-GRT p2 RegionA-CE01-GRT p2]
      bdlink %w[RegionA-PE01-GRT p3 RegionA-CE02-GRT p2]

      bdlink %w[RegionA-PE02-GRT p2 RegionA-CE01-GRT p3]
      bdlink %w[RegionA-PE02-GRT p3 RegionA-CE02-GRT p3]

      bdlink %w[RegionA-CE01-GRT p0 RegionA-CE01-GRT p0]
      bdlink %w[RegionA-CE01-GRT p4 RegionA-VL10 p0]
      bdlink %w[RegionA-CE01-GRT p5 RegionA-VL20 p0]

      bdlink %w[RegionA-CE02-GRT p4 RegionA-VL10 p1]
      bdlink %w[RegionA-CE02-GRT p5 RegionA-VL20 p1]

      bdlink %w[RegionA-CE01-VRF p4 RegionA-VL110 p0]
      bdlink %w[RegionA-CE01-VRF p5 RegionA-VL120 p0]

      bdlink %w[RegionA-CE02-VRF p4 RegionA-VL110 p1]
      bdlink %w[RegionA-CE02-VRF p5 RegionA-VL120 p1]

      bdlink %w[RegionA-VL10 p2 RegionA-Svr01 eno0]
      bdlink %w[RegionA-VL10 p3 RegionA-Svr02 eno0]

      bdlink %w[RegionA-VL110 p2 RegionA-Svr01 eno1]
      bdlink %w[RegionA-VL110 p3 RegionA-Svr02 eno1]

      # RegionB Nodes
      node 'RegionB-PE01-GRT' do
        (0..3).each { |i| term_point "p#{i}" }
        support %w[layer1 RegionB-PE01]
      end
      node 'RegionB-PE02-GRT' do
        (0..3).each { |i| term_point "p#{i}" }
        support %w[layer1 RegionB-PE02]
      end

      node 'RegionB-CE01-GRT' do
        (0..5).each { |i| term_point "p#{i}" }
        support %w[layer2 RegionB-CE01-GRT]
      end
      node 'RegionB-CE01-VRF' do
        (4..5).each { |i| term_point "p#{i}" }
        support %w[layer2 RegionB-CE01-VRF]
      end
      node 'RegionB-CE02-GRT' do
        (0..5).each { |i| term_point "p#{i}" }
        support %w[layer2 RegionB-CE02-GRT]
      end
      node 'RegionB-CE02-VRF' do
        (4..5).each { |i| term_point "p#{i}" }
        support %w[layer2 RegionB-CE02-VRF]
      end

      node 'RegionB-VL10' do
        (0..2).each { |i| term_point "p#{i}" }
        support %w[layer2 RegionB-CE01-VL10]
        support %w[layer2 RegionB-CE02-VL10]
        support %w[layer2 RegionB-Acc01-VL10]
      end
      node 'RegionB-VL20' do
        (0..2).each { |i| term_point "p#{i}" }
        support %w[layer2 RegionB-CE01-VL20]
        support %w[layer2 RegionB-CE02-VL20]
        support %w[layer2 RegionB-Acc02-VL20]
      end
      node 'RegionB-VL110' do
        (0..2).each { |i| term_point "p#{i}" }
        support %w[layer2 RegionB-CE01-VL110]
        support %w[layer2 RegionB-CE02-VL110]
        support %w[layer2 RegionB-Acc01-VL110]
      end
      node 'RegionB-VL120' do
        (0..2).each { |i| term_point "p#{i}" }
        support %w[layer2 RegionB-CE01-VL120]
        support %w[layer2 RegionB-CE02-VL120]
        support %w[layer2 RegionB-Acc02-VL120]
      end

      node 'RegionB-Svr01' do
        (0..1).each { |i| term_point "eno#{i}" }
        support %w[layer2 RegionB-Svr01]
      end
      node 'RegionB-Svr02' do
        (0..1).each { |i| term_point "eno#{i}" }
        support %w[layer2 RegionB-Svr02]
      end

      # RegionB Links
      bdlink %w[RegionB-PE01-GRT p0 RegionB-PE02-GRT p0]
      bdlink %w[RegionB-PE01-GRT p2 RegionB-CE01-GRT p2]
      bdlink %w[RegionB-PE01-GRT p3 RegionB-CE02-GRT p2]

      bdlink %w[RegionB-PE02-GRT p2 RegionB-CE01-GRT p3]
      bdlink %w[RegionB-PE02-GRT p3 RegionB-CE02-GRT p3]

      bdlink %w[RegionB-CE01-GRT p0 RegionB-CE01-GRT p0]
      bdlink %w[RegionB-CE01-GRT p4 RegionB-VL10 p0]
      bdlink %w[RegionB-CE01-GRT p5 RegionB-VL20 p0]

      bdlink %w[RegionB-CE02-GRT p4 RegionB-VL10 p1]
      bdlink %w[RegionB-CE02-GRT p5 RegionB-VL20 p1]

      bdlink %w[RegionB-CE01-VRF p4 RegionB-VL110 p0]
      bdlink %w[RegionB-CE01-VRF p5 RegionB-VL120 p0]

      bdlink %w[RegionB-CE02-VRF p4 RegionB-VL110 p1]
      bdlink %w[RegionB-CE02-VRF p5 RegionB-VL120 p1]

      bdlink %w[RegionB-VL10 p2 RegionB-Svr01 eno0]
      bdlink %w[RegionB-VL20 p2 RegionB-Svr02 eno0]

      bdlink %w[RegionB-VL110 p2 RegionB-Svr01 eno1]
      bdlink %w[RegionB-VL120 p2 RegionB-Svr02 eno1]

      # Inter Region Links
      bdlink %w[RegionA-PE01-GRT p1 RegionB-PE01-GRT p1]
      bdlink %w[RegionA-PE02-GRT p1 RegionB-PE02-GRT p1]
    end
  end
end
# rubocop:enable Metrics/MethodLength, Metrics/AbcSize
