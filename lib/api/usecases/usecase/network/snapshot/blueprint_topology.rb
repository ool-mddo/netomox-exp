# frozen_string_literal: true

require 'lib/api/rest_api_base'

module NetomoxExp
  module ApiRoute
    # blueprint topology stored in usecases directory
    class BlueprintTopology < RestApiBase
      desc 'Get blueprint topology'
      get 'topology' do
        usecase, network, snapshot = %i[usecase network snapshot].map { |key| params[key] }
        read_usecase_snapshot_topology(usecase, network, snapshot)
      end
    end
  end
end
