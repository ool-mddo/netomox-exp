# frozen_string_literal: true

require 'grape'
require 'lib/static_verification/layer1_verifier'
require 'lib/static_verification/layer1_ifdescr_generator'
require 'lib/static_verification/bgp_proc_verifier'

module NetomoxExp
  module ApiRoute
    # namespace /verify
    class StaticVerification < Grape::API
      namespace 'if_descr' do
        get do
          network, snapshot, layer = %i[network snapshot layer].map { |key| params[key] }
          begin
            generator = Layer1IfDescrGenerator.new(read_topology_instance(network, snapshot), layer)
            generator.records
          rescue StandardError => e
            error!("#{network}/#{snapshot}/#{layer} is insufficient: #{e}", 500)
          end
        end
      end

      namespace 'verify' do
        params do
          optional :severity, type: String, desc: 'severity', default: 'debug'
        end

        desc 'Verify bgp peer-attributes'
        get 'bgp_peer' do
          network, snapshot, layer = %i[network snapshot layer].map { |key| params[key] }
          begin
            verifier = BgpProcVerifier.new(read_topology_instance(network, snapshot), layer)
            verifier.verify(params[:severity])
          rescue StandardError => e
            error!("#{network}/#{snapshot}/#{layer} is insufficient: #{e}", 500)
          end
        end

        desc 'Verify interface description'
        get 'layer1' do
          network, snapshot, layer = %i[network snapshot layer].map { |key| params[key] }
          begin
            verifier = Layer1Verifier.new(read_topology_instance(network, snapshot), layer)
            verifier.verify(params[:severity])
          rescue StandardError => e
            error!("#{network}/#{snapshot}/#{layer} is insufficient: #{e}", 500)
          end
        end
      end
    end
  end
end
