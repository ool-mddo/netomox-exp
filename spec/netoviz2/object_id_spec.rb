# frozen_string_literal: true

require 'lib/netoviz2/object_id'

RSpec.describe NetomoxExp::Netoviz2::ObjectId do
  describe '.layer' do
    it 'keeps simple network names' do
      expect(described_class.layer('layer3')).to eq 'layer3'
      expect(described_class.layer('ospf_area0')).to eq 'ospf_area0'
    end
  end

  describe '.node' do
    it 'encodes slashes in node names' do
      expect(described_class.node('layer3', 'Seg_172.32.0.0/30')).to eq 'layer3/Seg_172.32.0.0%2F30'
    end
  end

  describe '.tp' do
    it 'encodes slashes in tp names' do
      expect(described_class.tp('layer3', 'site-a-br-1', 'ge-0/0/0.0')).to eq 'layer3/site-a-br-1/ge-0%2F0%2F0.0'
    end

    it 'distinguishes names whose plain concatenation would be ambiguous' do
      # node "a/b" + tp "c"  vs  node "a" + tp "b/c"
      expect(described_class.tp('nw', 'a/b', 'c')).not_to eq described_class.tp('nw', 'a', 'b/c')
    end
  end

  describe '.link' do
    it 'treats the whole link-id as one segment' do
      link_id = 'Seg_172.32.0.0/30,site-a-br-1_ge-0/0/0.0,site-a-br-1,ge-0/0/0.0'
      id = described_class.link('layer3', link_id)
      expect(id).to eq 'layer3/~link/Seg_172.32.0.0%2F30%2Csite-a-br-1_ge-0%2F0%2F0.0%2Csite-a-br-1%2Cge-0%2F0%2F0.0'
      expect(id.count('/')).to eq 2
    end

    it 'never collides with a node or a tp, even if their names look like the marker' do
      node = described_class.node('nw', 'x')
      expect(described_class.link('nw', 'x')).not_to eq node
      # node "~link" + tp "x"  vs  link "x"
      expect(described_class.tp('nw', '~link', 'x')).not_to eq described_class.link('nw', 'x')
    end
  end

  describe 'special characters' do
    it 'encodes percent, space, plus and non-ascii characters' do
      expect(described_class.segment('a%b c+d')).to eq 'a%25b%20c%2Bd'
      expect(described_class.segment('ノード')).to eq '%E3%83%8E%E3%83%BC%E3%83%89'
    end

    it 'encodes tilde (used as the marker of link ids)' do
      expect(described_class.segment('~link')).to eq '%7Elink'
    end

    it 'does not use a plus sign for spaces (decodable with percent-decoding only)' do
      expect(described_class.segment('a b')).not_to include('+')
    end
  end
end
