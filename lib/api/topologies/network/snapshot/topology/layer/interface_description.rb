# frozen_string_literal: true

require 'grape'
require 'lib/interface_descr/interface_descr_checker'
require 'lib/interface_descr/interface_descr_generator'

module NetomoxExp
  module ApiRoute
    # namespace /interface_description
    class InterfaceDescription < Grape::API
      desc 'Generate interface description'
      namespace 'interface_description' do
        get do
          network, snapshot, layer = %i[network snapshot layer].map { |key| params[key] }
          begin
            generator = InterfaceDescrGenerator.new(read_topology_instance(network, snapshot), layer)
            generator.records
          rescue StandardError => e
            error!("#{network}/#{snapshot}/#{layer} is insufficient: #{e}", 404)
          end
        end

        desc 'Check interface description'
        params do
          optional :severity, type: String, desc: 'severity (warning/error)', default: 'warning'
        end
        get 'check' do
          network, snapshot, layer = %i[network snapshot layer].map { |key| params[key] }
          begin
            verifier = InterfaceDescrChecker.new(read_topology_instance(network, snapshot), layer)
            verifier.verify_description(params[:severity])
          rescue StandardError => e
            error!("#{network}/#{snapshot}/#{layer} is insufficient: #{e}", 404)
          end
        end
      end
    end
  end
end
