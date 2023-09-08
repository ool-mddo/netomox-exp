# frozen_string_literal: true

require 'grape'

module NetomoxExp
  module ApiRoute
    # namespace /external_as_topology
    class ExternalAsTopology < Grape::API
      # namespace /external_as_topology
      resource 'external_as_topology' do
        get do
          network, snapshot = %i[network snapshot].map { |key| params[key] }
          # NOTE: to `load` topology script, it must be absolute-path
          #   see also: https://docs.ruby-lang.org/ja/latest/method/Kernel/m/load.html
          ext_topo_dir = File.join(CONFIGS_DIR, network, snapshot, 'external_as_topology')
          puts "# DEBUG: ext_topo_dir=#{ext_topo_dir}"
          error!("#{network}/#{snapshot} does not have external-AS topology dir", 404) unless Dir.exist?(ext_topo_dir)

          ext_topo_script = File.join(ext_topo_dir, 'main.rb')
          error!("External-AS topology script is not found in #{ext_topo_dir}", 404) unless File.exist?(ext_topo_script)

          # param [String] script
          # return [String] external-AS topology data (RFC8345 json string)
          generate_topology_proc = lambda do |script|
            # (re)load every call
            load script
            # the script defines `generate_topology` function that returns RFC8345 topology json string as external-AS
            generate_topology
          end

          # response
          generate_topology_proc.call(ext_topo_script)
        end
      end
    end
  end
end
