# frozen_string_literal: true

require 'grape'

module NetomoxExp
  module ApiRoute
    # namespace /external_as_topology
    class ExternalAsTopology < Grape::API
      # namespace /external_as_topology
      resource 'external_as_topology' do
        params do
          requires :usecase, type: String, desc: 'Usecase name'
          optional :options, type: Hash, desc: 'Option parameters to generate external-AS topology'
        end
        post do
          network, snapshot = %i[network snapshot].map { |key| params[key] }
          usecase = params[:usecase]
          options = params.key?(:options) ? params[:options] : {}

          # NOTE: absolute-path of external_as_script
          ext_topo_dir = File.join(CONFIGS_DIR, network, snapshot, 'external_as_topology', usecase)
          unless Dir.exist?(ext_topo_dir)
            error!("External-AS topology dir: #{network}/#{snapshot}/external_as_topology/#{usecase} is not found", 404)
          end

          ext_topo_script = File.join(ext_topo_dir, 'main.rb')
          error!("External-AS topology script is not found in #{ext_topo_dir}", 404) unless File.exist?(ext_topo_script)

          load ext_topo_script
          generate_topology(options) # defined in ext_topo_script
        end
      end
    end
  end
end
