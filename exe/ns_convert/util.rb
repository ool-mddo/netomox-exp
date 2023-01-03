# frozen_string_literal: true

module TopologyOperator
  # namespace converter
  class NamespaceConverter < NamespaceConvertTable
    ATTR_KEY_TABLE = {
      static_route: :static_routes,
      neighbor: :neighbors,
      prefix: :prefixes,
      ip_address: :ip_addrs,
      flag: :flags
    }.freeze


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

    # Convert attributes in Netomox::Topology object to TopologyBuilder::PseudoDSL object
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
end
