# frozen_string_literal: true

require_relative 'table_base'

module NetomoxExp
  module TopologyBuilder
    module CSVMapper
      # row of routes table
      class RoutesTableRecord < TableRecordBase
        # @!attribute [rw] node
        #   @return [String]
        # @!attribute [rw] vrf
        #   @return [String]
        # @!attribute [rw] network
        #   @return [String]
        # @!attribute [rw] next_hop
        #   @return [String]
        # @!attribute [rw] next_hop_ip
        #   @return [String]
        # @!attribute [rw] next_hop_interface
        #   @return [String]
        # @!attribute [rw] protocol
        #   @return [String]
        # @!attribute [rw] metric
        #   @return [Integer]
        # @!attribute [rw] admin_distance
        #   @return [Integer]
        attr_accessor :node, :vrf, :network, :next_hop, :next_hop_ip, :next_hop_interface,
                      :protocol, :metric, :admin_distance

        # @param [Enumerable] record A row of csv_mapper table
        def initialize(record)
          super()
          @node = record[:node]
          @vrf = record[:vrf]
          @network = record[:network]
          @next_hop = record[:next_hop]
          # Newer Batfish releases drop the legacy Next_Hop_IP/Next_Hop_Interface columns,
          # so fall back to decomposing the Next_Hop column when they are absent.
          @next_hop_ip = record[:next_hop_ip] || parse_next_hop(@next_hop)[:ip]
          @next_hop_interface = record[:next_hop_interface] || parse_next_hop(@next_hop)[:interface]
          @protocol = record[:protocol]
          @metric = record[:metric]
          @admin_distance = record[:admin_distance]
        end

        # @param [String] protocol Protocol name
        # @return [Boolean]
        def protocol?(protocol)
          @protocol == protocol.downcase
        end

        # @return [String]
        def to_s
          "#{@node}, #{@network}, #{@next_hop_ip}(#{@next_hop_interface})"
        end

        private

        # Decompose Batfish `Next_Hop` string into legacy column values.
        # @param [String, nil] next_hop Next_Hop column (e.g. "interface eth0 ip 192.168.0.1", "ip 192.168.0.1",
        #   "interface eth0", "discard")
        # @return [Hash] { ip: String or nil, interface: String or nil }
        #   (same values as the legacy Next_Hop_IP/Next_Hop_Interface columns)
        def parse_next_hop(next_hop)
          return { ip: nil, interface: nil } if next_hop.nil?
          return { ip: 'AUTO/NONE(-1l)', interface: 'null_interface' } if next_hop == 'discard'

          interface = next_hop[/\binterface (\S+)/, 1]
          ip_addr = next_hop[/\bip (\S+)/, 1]
          # the legacy columns use these placeholders when one of the elements is missing
          { ip: ip_addr || 'AUTO/NONE(-1l)', interface: interface || 'dynamic' }
        end
      end

      # routes table
      class RoutesTable < TableBase
        # @param [String] target Target network (config) data name
        def initialize(target)
          super(target, 'routes.csv')
          @records = @orig_table.map { |r| RoutesTableRecord.new(r) }
        end

        # @param [String] node_name Node name to find
        # @return [Array<RoutesTableRecord>] Found records
        def find_all_records_by_node(node_name)
          @records.find_all { |r| r.node == node_name }
        end

        # @param [String] node_name Node name to find
        # @param [String] proto_name Protocol name to find
        # @return [Array<RoutesTableRecord>] Found records
        def find_all_records_by_node_proto(node_name, proto_name)
          find_all_records_by_node(node_name).find_all { |r| r.protocol?(proto_name) }
        end
      end
    end
  end
end
