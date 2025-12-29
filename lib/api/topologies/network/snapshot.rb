# frozen_string_literal: true

require 'grape'
require 'lib/api/rest_api_base'
require_relative 'snapshot/converted_topology'
require_relative 'snapshot/topology/layer'
require_relative 'snapshot/topology'

module NetomoxExp
  module ApiRoute
    # namespace /snapshot
    class Snapshot < RestApiBase
      params do
        requires :snapshot, type: String, desc: 'Snapshot name'
      end
      resource ':snapshot' do
        mount ApiRoute::ConvertedTopology
        mount ApiRoute::Topology
      end
    end
  end
end
