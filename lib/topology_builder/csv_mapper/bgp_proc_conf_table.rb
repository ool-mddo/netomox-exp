# frozen_string_literal: true

require_relative 'table_base'

module NetomoxExp
  module TopologyBuilder
    module CSVMapper
      # row of bgp process configuration table
      class BgpProcessConfigurationTableRecord < TableRecordBase
        # @!attribute [rw] node
        #   @return [String]
        # @!attribute [rw] vrf
        #   @return [String]
        # @!attribute [rw] router_id
        #   @return [String]
        # @!attribute [rw] confederation_id
        #   @return [String]
        # @!attribute [rw] confederation_members
        #   @return [Array<Integer>]
        # @!attribute [rw] multipath_ebgp
        #   @return [Boolean]
        # @!attribute [rw] multipath_ibgp
        #   @return [Boolean]
        # @!attribute [rw] multipath_match_mode
        #   @return [String]
        # @!attribute [rw] neighbors
        #   @return [Array<String>]
        # @!attribute [rw] route_reflector
        #   @return [Boolean]
        # @!attribute [rw] tie_breaker
        #   @return [String]
        attr_accessor :node, :vrf, :router_id, :confederation_id, :confederation_members, :multipath_ebgp,
                      :multipath_ibgp, :multipath_match_mode, :neighbors, :route_reflector, :tie_breaker

        # rubocop:disable Metrics/MethodLength, Metrics/AbcSize

        # @param [Enumerable] record A row of csv_mapper table
        def initialize(record)
          super()
          @node = record[:node]
          @vrf = record[:vrf]
          @router_id = record[:router_id]
          @confederation_id = record[:confederation_id]

          cf_nums = record[:confederation_members]
          @confederation_members = cf_nums.instance_of?(Integer) ? [cf_nums] : parse_array_string(cf_nums).map(&:to_i)

          @multipath_ebgp = true_string?(record[:multipath_ebgp])
          @multipath_ibgp = true_string?(record[:multipath_ebgp])
          @multipath_match_mode = record[:multipath_match_mode]
          @neighbors = parse_array_string(record[:neighbors])
          @route_reflector = true_string?(record[:route_reflector])
          @tie_breaker = record[:tie_breaker]
        end
        # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

        # @return [Boolean] true if GRT ip info (not VRF instance)
        def grt?
          @vrf == 'default'
        end
      end

      # bgp process configuration table
      class BgpProcessConfigurationTable < TableBase
        # @param [String] target Target network (config) data name
        def initialize(target)
          super(target, 'bgp_proc_conf.csv')
          @records = @orig_table.map { |r| BgpProcessConfigurationTableRecord.new(r) }
        end

        # @param [String] node Node name
        # @param [String] vrf Vrf name
        # @return [BgpPeerConfigurationTableRecord, nil] found record
        def find_rec_by_node_vrf(node, vrf = 'default')
          @records.find { |rec| rec.node == node && rec.vrf == vrf }
        end

        # @param [String] router_id
        # @return [BgpProcessConfigurationTableRecord, nil] found record
        def find_rec_by_router_id(router_id)
          @records.find { |rec| rec.router_id == router_id }
        end
      end
    end
  end
end
