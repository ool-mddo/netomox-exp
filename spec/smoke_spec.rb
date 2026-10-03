# frozen_string_literal: true

require 'app'

RSpec.describe NetomoxExp::NetomoxRestApi do
  it 'is loadable' do
    expect(described_class).to be < Grape::API
  end
end
