# frozen_string_literal: true

require 'json'

module NetomoxExp
  # Base class of namespace converter
  class NamespaceConverterBase
    # Target Network Types
    UPPER_LAYER3_NWTYPE_LIST = [
      Netomox::NWTYPE_MDDO_L3,
      Netomox::NWTYPE_MDDO_OSPF_AREA,
      Netomox::NWTYPE_MDDO_BGP_PROC,
      Netomox::NWTYPE_MDDO_BGP_AS
    ].freeze

    # Table of the keys which can not convert standard way (exceptional keys in L3/OSPF network)
    # Netomox::Topology attribute (object) -> Netomox::PseudoDSL attribute (Simple Hash)
    # NOTE: these keys are a list excepting `ip_addr`/`ip_address`
    PLURAL_ATTR_KEY_TABLE = {
      # plural + abbreviation key
      ip_address: :ip_addrs,
      # plural keys
      static_route: :static_routes,
      neighbor: :neighbors,
      prefix: :prefixes,
      flag: :flags,
      confederation_member: :confederation_members,
      peer_group: :peer_groups,
      policy: :policies,
      import_policy: :import_policies,
      export_policy: :export_policies,
      redistribute: :redistribute_list
    }.freeze

    def initialize
      # NOTE: initialized in #make_convert_table method:
      #   used when construct convert table from topology data
      @src_nws = nil
    end

    # @param [Hash] topology_data Topology data (RFC8345 Hash)
    # @return [void]
    # @raise [StandardError]
    def load_origin_topology(topology_data)
      @src_nws = Netomox::Topology::Networks.new(topology_data)
      @over_layer3_nw_names = upper_layer3_network_names
    end

    protected

    # @return [Array<String>] Network names (upper layer3)
    def upper_layer3_network_names
      nw_names = UPPER_LAYER3_NWTYPE_LIST.map do |network_type|
        @src_nws&.find_all_networks_by_type(network_type)&.map(&:name)
      end
      nw_names.flatten.compact
    end

    # @param [String] network_name Network (layer) name
    # @return [Boolean] True if the network_name matches one of TARGET_NW_REGEXP_LIST
    def target_network?(network_name)
      @over_layer3_nw_names.include?(network_name)
    end

    # @param [Symbol] key Key to convert
    # @param [Array, Object] value
    # @return [Symbol] Converted key
    def convert_hash_key(key, value)
      # convert key symbol (external key like 'os-type') to snake_case symbol (:os_type)
      converted_key = key.to_s.tr('-', '_').to_sym
      return PLURAL_ATTR_KEY_TABLE[converted_key] if value.is_a?(Array) && PLURAL_ATTR_KEY_TABLE.key?(converted_key)

      # NOTE: irregular
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
end
