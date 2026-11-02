# frozen_string_literal: true

require 'lib/netoviz2/model_cache'

RSpec.describe NetomoxExp::Netoviz2::ModelCache do
  let(:cache) { described_class.new(2) }

  it 'builds a model only once for the same key' do
    builds = 0
    2.times { cache.fetch_or_build(%w[nw ss e1]) { (builds += 1) && :model } }
    expect(builds).to eq 1
  end

  it 'builds again when the key (etag) is changed' do
    expect(cache.fetch_or_build(%w[nw ss e1]) { :old }).to eq :old
    expect(cache.fetch_or_build(%w[nw ss e2]) { :new }).to eq :new
  end

  it 'evicts the least recently used model' do
    cache.fetch_or_build(%w[a ss e]) { :a }
    cache.fetch_or_build(%w[b ss e]) { :b }
    cache.fetch_or_build(%w[a ss e]) { :unexpected } # a is used recently
    cache.fetch_or_build(%w[c ss e]) { :c }          # b is evicted
    expect(cache.size).to eq 2
    expect(cache.fetch_or_build(%w[a ss e]) { :rebuilt }).to eq :a
    expect(cache.fetch_or_build(%w[b ss e]) { :rebuilt }).to eq :rebuilt
  end

  it 'does not keep the model when building fails' do
    expect { cache.fetch_or_build(%w[nw ss e]) { raise 'broken' } }.to raise_error('broken')
    expect(cache.size).to eq 0
  end
end
