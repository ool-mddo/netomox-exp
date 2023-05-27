# frozen_string_literal: true

$LOAD_PATH.unshift File.dirname(__FILE__)

require_relative 'lib/api/rest_api_base'
require_relative 'lib/api/topologies'

module NetomoxExp
  # Directory to save batfish query answers
  QUERIES_DIR = ENV.fetch('MDDO_QUERIES_DIR', 'queries')
  # Directory to save topology json from batfish query answers
  TOPOLOGIES_DIR = ENV.fetch('MDDO_TOPOLOGIES_DIR', 'topologies')
  # (temporary) layout file directory
  MODEL_DEFS_DIR = './model_defs'

  # Netomox REST API definition
  class NetomoxRestApi < RestApiBase
    mount ApiRoute::Topologies
  end
end
