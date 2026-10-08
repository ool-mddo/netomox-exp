# frozen_string_literal: true

require 'rack/test'

# helpers for API (rack-test) specs
#   MDDO_*_DIR are temporary directories (see spec_helper.rb)
module ApiHelper
  include Rack::Test::Methods

  QUERIES_DIR = ENV.fetch('MDDO_QUERIES_DIR')
  TOPOLOGIES_DIR = ENV.fetch('MDDO_TOPOLOGIES_DIR')
  USECASES_DIR = ENV.fetch('MDDO_USECASES_DIR')

  def app
    NetomoxExp::NetomoxRestApi
  end

  # @return [Object] parsed json of last response
  def json_body
    JSON.parse(last_response.body)
  end

  # copy fixtures to temporary dirs (call in `before`)
  def prepare_dirs
    [QUERIES_DIR, TOPOLOGIES_DIR, USECASES_DIR].each { |d| FileUtils.rm_rf(d) }
    FileUtils.mkdir_p([QUERIES_DIR, TOPOLOGIES_DIR, USECASES_DIR])
    FileUtils.cp_r(FixtureHelper.path('queries', 'mddo-fw'), QUERIES_DIR)
    FileUtils.cp_r(FixtureHelper.path('usecases', 'refocus_topology'), USECASES_DIR)
  end

  # @param [Hash] data request body (json)
  def post_json(path, data = {})
    post path, JSON.generate(data), 'CONTENT_TYPE' => 'application/json'
  end

  # register a topology data directly (without generation)
  def register_topology(network, snapshot, topology_data)
    post_json "/topologies/#{network}/#{snapshot}/topology", { topology_data: topology_data }
  end
end
