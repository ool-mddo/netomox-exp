# frozen_string_literal: true

require 'lib/netoviz2/model'
require 'lib/netoviz2/layer_builder'
require 'lib/netoviz2/model_cache'
require 'lib/netoviz2/summary_builder'

module NetomoxExp
  # helpers for netoviz2 API (see lib/api/topologies/network/snapshot/netoviz2_api.rb)
  module Netoviz2ApiHelpers
    # Max number of ids in a request of attributes
    MAX_ATTRIBUTE_IDS = 200
    # Cache of models (shared by requests; keyed by network, snapshot and ETag of the topology file)
    MODEL_CACHE = Netoviz2::ModelCache.new

    # @return [String] ETag of the topology file (changes when the file is updated or the schema is changed)
    def netoviz2_etag(network, snapshot)
      file = File.join(TOPOLOGIES_DIR, network, snapshot, 'topology.json')
      error!("Not found: #{file}", 404) unless File.exist?(file)

      stat = File.stat(file)
      "v#{Netoviz2::SummaryBuilder::SCHEMA_VERSION}-#{(stat.mtime.to_i * 1_000_000_000) + stat.mtime.nsec}-#{stat.size}"
    end

    # @return [Boolean] true if the client has the current data (If-None-Match)
    def netoviz2_not_modified?(etag)
      request.env['HTTP_IF_NONE_MATCH']&.delete_prefix('W/') == %("#{etag}")
    end

    # @param [String] etag ETag of the topology file (cache key)
    # @return [Netoviz2::Model]
    def netoviz2_model(network, snapshot, etag)
      MODEL_CACHE.fetch_or_build([network, snapshot, etag]) do
        Netoviz2::Model.new(read_topology_instance(network, snapshot))
      end
    rescue StandardError => e
      raise if netoviz2_halt?(e)

      logger.error("[netoviz2] invalid topology #{network}/#{snapshot}: #{e.class}: #{e.message}")
      error!("Invalid topology data: #{e.class}: #{e.message}", 500)
    end

    # @param [Netoviz2::Model] model Model
    # @param [String] layer_id Layer ID
    # @return [Hash] structure of the layer (404 if not found)
    def netoviz2_layer_data(model, layer_id)
      Netoviz2::LayerBuilder.new(model).build(layer_id) || error!("Layer not found: #{layer_id}", 404)
    end

    # @param [Object] ids Requested object IDs
    # @return [Array<String>] validated ids (422 if it is not an array of strings, is empty or too large)
    def netoviz2_attribute_ids(ids)
      error!('ids (array of string) is required', 422) unless ids.is_a?(Array) && !ids.empty? && ids.all?(String)
      error!("Too many ids (max #{MAX_ATTRIBUTE_IDS})", 422) if ids.size > MAX_ATTRIBUTE_IDS

      ids
    end

    # @param [Boolean] conditional Set ETag header and respond 304 when If-None-Match matches (GET only)
    # @yield [network, snapshot, etag, model] block to make response body (Hash)
    # @return [Hash,String] response body (empty string if not modified)
    def netoviz2_respond(conditional: true)
      network, snapshot = %i[network snapshot].map { |key| params[key] }
      etag = netoviz2_etag(network, snapshot)
      if conditional
        header 'ETag', %("#{etag}")
        return netoviz2_not_modified_response if netoviz2_not_modified?(etag)
      end

      netoviz2_guard { yield(network, snapshot, etag, netoviz2_model(network, snapshot, etag)) }
    end

    # Make a bug in the builders a json response with log
    # (invalid topology data is handled in #netoviz2_model)
    def netoviz2_guard
      yield
    rescue StandardError => e
      raise if netoviz2_halt?(e)

      logger.error("[netoviz2] #{e.class}: #{e.message}\n#{e.backtrace&.first(10)&.join("\n")}")
      error!("Internal error: #{e.class}: #{e.message}", 500)
    end

    # `error!` raises an exception of Grape (Grape::Exceptions::Halt in Grape 4, thrown in older versions).
    # It is an expected response, not an error to be converted.
    # @param [Exception] error Rescued exception
    # @return [Boolean]
    def netoviz2_halt?(error)
      error.class.name.to_s.start_with?('Grape::')
    end

    # @return [String] empty body
    def netoviz2_not_modified_response
      status 304
      ''
    end
  end
end
