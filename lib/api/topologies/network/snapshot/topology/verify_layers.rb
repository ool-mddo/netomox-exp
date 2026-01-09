# frozen_string_literal: true

require 'lib/api/rest_api_base'
require 'lib/static_verifier/static_verifier'

module NetomoxExp
  module ApiRoute
    # resource /verify
    class VerifyLayers < RestApiBase
      resource 'verify' do
        desc 'Verify all network layer'
        params do
          optional :severity, type: String, desc: 'severity', default: 'debug'
        end
        get do
          network, snapshot, severity = %i[network snapshot severity].map { |key| params[key] }
          log_table = {}
          begin
            topology = read_topology_instance(network, snapshot)
            topology.networks.each do |nw_layer|
              verifier_class = StaticVerifier.verifier_by_network_type(nw_layer)
              verifier = verifier_class.new(topology, nw_layer.name)
              log_table[nw_layer.name] = verifier.verify(severity)
            end
            # reply
            log_table
          rescue StandardError => e
            warn e, e.backtrace
            error!("#{network}/#{snapshot} is insufficient: #{e}", 500)
          end
        end
      end
    end
  end
end
