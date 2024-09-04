# frozen_string_literal: true

require 'grape'
require 'lib/static_verifier/static_verifier'

module NetomoxExp
  module ApiRoute
    # namespace /verify
    class VerifyLayer < Grape::API
      namespace 'verify' do
        desc 'Verify specified layer as its network-type'
        params do
          optional :severity, type: String, desc: 'severity', default: 'debug'
        end
        get do
          network, snapshot, layer, severity = %i[network snapshot layer severity].map { |key| params[key] }
          begin
            topology = read_topology_instance(network, snapshot)
            target_layer = topology.find_network(layer)
            error!("#{network}/#{layer} is not found", 404) if target_layer.nil?

            verifier_class = StaticVerifier.verifier_by_network_type(target_layer)
            verifier = verifier_class.new(topology, layer)
            # reply
            verifier.verify(severity)
          rescue StandardError => e
            warn e, e.backtrace
            error!("#{network}/#{snapshot}/#{layer} is insufficient: #{e}", 500)
          end
        end
      end
    end
  end
end
