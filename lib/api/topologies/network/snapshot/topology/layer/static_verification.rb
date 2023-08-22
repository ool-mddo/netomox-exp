# frozen_string_literal: true

require 'grape'
require 'lib/static_verification/interface_descr/interface_descr_checker'
require 'lib/static_verification/interface_descr/interface_descr_generator'
require 'lib/static_verification/bgp_proc_verifier'

module NetomoxExp
  module ApiRoute
    # namespace /verify
    class StaticVerification < Grape::API
      namespace 'if_descr' do
        get do
          network, snapshot, layer = %i[network snapshot layer].map { |key| params[key] }
          begin
            generator = InterfaceDescrGenerator.new(read_topology_instance(network, snapshot), layer)
            generator.records
          rescue StandardError => e
            error!("#{network}/#{snapshot}/#{layer} is insufficient: #{e}", 500)
          end
        end
      end

      namespace 'verify' do
        params do
          optional :severity, type: String, desc: 'severity (warning/error)', default: 'warning'
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
        get 'if_descr' do
          network, snapshot, layer = %i[network snapshot layer].map { |key| params[key] }
          begin
            verifier = InterfaceDescrChecker.new(read_topology_instance(network, snapshot), layer)
            verifier.verify_description(params[:severity])
          rescue StandardError => e
            error!("#{network}/#{snapshot}/#{layer} is insufficient: #{e}", 500)
          end
        end
      end
    end
  end
end
