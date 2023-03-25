# frozen_string_literal: true

require 'json'
require 'netomox'

# Base class of namespace converter
class NamespaceConverterBase
  # Target network (layer) names (regexp match)
  TARGET_NW_REGEXP_LIST = [/ospf_area\d+/, /layer3/].freeze

  # Table of the keys which can not convert standard way (exceptional keys in L3/OSPF network)
  # Netomox::Topology attribute (object) -> Netomox::PseudoDSL attribute (Simple Hash)
  # NOTE: these keys are a list excepting `ip_addr`/`ip_address`
  ATTR_KEY_TABLE = {
    static_route: :static_routes,
    neighbor: :neighbors,
    prefix: :prefixes,
    ip_address: :ip_addrs,
    flag: :flags
  }.freeze

  # @param [Hash] topology_data Topology data
  def initialize(topology_data)
    @src_nws = Netomox::Topology::Networks.new(topology_data)
  end

  protected

  # @param [String] network_name Network (layer) name
  # @return [Boolean] True if the network_name matches one of TARGET_NW_REGEXP_LIST
  def target_network?(network_name)
    TARGET_NW_REGEXP_LIST.any? { |nw_re| network_name =~ nw_re }
  end

  # @param [Symbol] key Key to convert
  # @param [Array, Object] value
  # @return [Symbol] Converted key
  def convert_hash_key(key, value)
    # convert key symbol to snake_case
    converted_key = key.to_s.tr('-', '_').to_sym
    return ATTR_KEY_TABLE[converted_key] if value.is_a?(Array) && ATTR_KEY_TABLE.key?(converted_key)

    return :ip_addr if converted_key == :ip_address

    converted_key
  end

  # Convert attributes in Netomox::Topology object to Netomox::PseudoDSL object
  # @param [Hash,Array,Object] value Hash data to convert its key symbol
  # @return [Hash,Array,Object] converted hash
  def convert_all_hash_keys(value)
    case value
    when Array
      value.map { |v| convert_all_hash_keys(v) }
    when Hash
      value.delete('_diff_state_') if value.key?('_diff_state_')
      value.delete('router-id-source') if value.key?('router-id-source')
      value.to_h { |k, v| [convert_hash_key(k, v), convert_all_hash_keys(v)] }
    else
      value
    end
  end
end
