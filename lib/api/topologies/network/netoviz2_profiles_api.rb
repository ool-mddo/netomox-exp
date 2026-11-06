# frozen_string_literal: true

require 'lib/api/rest_api_base'
require 'lib/netoviz2/profile_files'

module NetomoxExp
  module ApiRoute
    # namespace /netoviz2/profiles : diagram profiles of a network for netoviz2
    #   (see docs/netoviz2_data_format.md in playground)
    #   It is not under a snapshot: the profile files tell the snapshots they are applied to (`target.snapshot`).
    class Netoviz2ProfilesApi < RestApiBase
      resource 'netoviz2' do
        desc 'Diagram profiles of the network (YAML files converted to JSON)'
        get 'profiles' do
          {
            network: params[:network],
            profiles: Netoviz2::ProfileFiles.new(PROFILES_DIR).list(params[:network])
          }
        end
      end
    end
  end
end
