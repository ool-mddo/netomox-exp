# frozen_string_literal: true

require 'grape'
require 'lib/static_verification/static_verifier'

module NetomoxExp
  module ApiRoute
    # namespace /verify
    class StaticVerification < Grape::API
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

            verifier_class = StaticVerifier.verifier_by_network_type(target_layer)
            verifier = verifier_class.new(topology, layer)
            verifier.verify(severity)
          rescue StandardError => e
            error!("#{network}/#{snapshot}/#{layer} is insufficient: #{e}", 500)
          end
        end
      end
    end
  end
end
