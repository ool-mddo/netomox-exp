# frozen_string_literal: true

require_relative 'table_base'

module NetomoxExp
  module TopologyBuilder
    module CSVMapper
      # row of bgp peer configuration table
      class BgpPeerConfigurationTableRecord < TableRecordBase
        # @!attribute [rw] node
        #   @return [String]
        # @!attribute [rw] vrf
        #   @return [String]
        # @!attribute [rw] local_as
        #   @return [Integer]
        # @!attribute [rw] local_ip
        #   @return [String]
        # @!attribute [rw] local_interface
        #   @return [String]
        # @!attribute [rw] confederation
        #   @return [Integer]
        # @!attribute [rw] remote_as
        #   @return [Integer]
        # @!attribute [rw] remote_ip
        #   @return [String]
        # @!attribute [rw] description
        #   @return [String]
        # @!attribute [rw] route_reflector_client
        #   @return [Boolean]
        # @!attribute [rw] cluster_id
        #   @return [String]
        # @!attribute [rw] peer_group
        #   @return [String]
        # @!attribute [rw] import_policy
        #   @return [Array<String>]
        # @!attribute [rw] export_policy
        #   @return [Array<String>]
        # @!attribute [rw] send_community
        #   @return [Boolean]
        # @!attribute [rw] is_passive
        #   @return [Boolean]
        attr_accessor :node, :vrf, :local_as, :local_ip, :local_interface, :confederation, :remote_as, :remote_ip,
                      :description, :route_reflector_client, :cluster_id, :peer_group, :import_policy, :export_policy,
                      :send_community, :is_passive

        # rubocop:disable Metrics/MethodLength, Metrics/AbcSize

        # @param [Enumerable] record A row of csv_mapper table
        def initialize(record)
          super()
          @node = record[:node]
          @vrf = record[:vrf]
          @local_as = record[:local_as]
          @local_ip = record[:local_ip]
          @local_interface = record[:local_interface]
          @confederation = record[:confederation]
          @remote_as = record[:remote_as]
          @remote_ip = record[:remote_ip]
          @description = record[:description]
          @route_reflector_client = true_string?(record[:route_reflector_client])
          @cluster_id = record[:cluster_id]
          @peer_group = record[:peer_group]
          @import_policy = parse_array_string(record[:import_policy])
          @export_policy = parse_array_string(record[:export_policy])
          @send_community = true_string?(record[:send_community])
          @is_passive = true_string?(record[:is_passive])
        end
        # rubocop:enable Metrics/MethodLength, Metrics/AbcSize
      end

      # bgp peer configuration table
      class BgpPeerConfigurationTable < TableBase
        # @param [String] target Target network (config) data name
        def initialize(target)
          super(target, 'bgp_peer_conf.csv')
          @records = @orig_table.map { |r| BgpPeerConfigurationTableRecord.new(r) }
        end

        # @param [String] local_ip Local IP
        # @param [String] remote_ip Remote IP
        # @return [Array<BgpPeerConfigurationTableRecord>] found records
        def find_all_recs_by_end_ip(local_ip, remote_ip)
          @records.find_all { |rec| rec.local_ip == local_ip && rec.remote_ip == remote_ip }
        end

        # @param [String] node Node name
        # @param [String] vrf Vrf name
        # @return [Array<BgpPeerConfigurationTableRecord>] found records
        def find_all_recs_by_node_vrf(node, vrf = 'default')
          @records.find_all { |rec| rec.node == node && rec.vrf == vrf }
        end
      end
    end
  end
end
