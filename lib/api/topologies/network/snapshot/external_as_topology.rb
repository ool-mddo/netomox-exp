# frozen_string_literal: true

require 'grape'
require 'json'
require 'open3'

module NetomoxExp
  module ApiRoute
    # namespace /external_as_topology
    class ExternalAsTopology < Grape::API
      # namespace /external_as_topology
      resource 'external_as_topology' do
        get do
          network, snapshot = %i[network snapshot].map { |key| params[key] }
          # NOTE: absolute-path of external_as_script
          ext_topo_dir = File.join(CONFIGS_DIR, network, snapshot, 'external_as_topology')
          error!("#{network}/#{snapshot} does not have external-AS topology dir", 404) unless Dir.exist?(ext_topo_dir)

          ext_topo_script = File.join(ext_topo_dir, 'main.rb')
          error!("External-AS topology script is not found in #{ext_topo_dir}", 404) unless File.exist?(ext_topo_script)

          command = "ruby #{ext_topo_script}"
          logger.info "Call external script: #{command}"
          output, _status = Open3.capture2(command)
          JSON.parse(output)
        end
      end
    end
  end
end
