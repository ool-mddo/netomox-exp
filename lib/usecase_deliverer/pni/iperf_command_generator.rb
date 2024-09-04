# frozen_string_literal: true

require 'ipaddr'

module NetomoxExp
  module UsecaseDeliverer
    # iperf command generator for pni_te/pni_addlink usecase
    class IperfCommandGenerator
      # @param [Array] flow_data_list Flow data
      # @param [Array] l3endpoint_list L3 endpoint list
      def initialize(flow_data_list, l3endpoint_list)
        @flow_data_list = flow_data_list
        @l3endpoint_list = l3endpoint_list
      end

      # @return [Array<Hash>] iperf_commands iPerf commands
      def generate_iperf_commands
        # combine L3 endpoint information with flow data
        l3endpoint = create_l3endpoint_dict
        iperf_commands = create_iperf_commands(l3endpoint)
        assign_port_number(iperf_commands)
      end

      private

      # @param [Array<Hash>] iperf_commands iPerf commands
      # @return [Array] updated iperf_commands
      def assign_port_number(iperf_commands)
        sorted_iperf_commands = iperf_commands.sort_by { |iperf_cmd| iperf_cmd['server_node'] }
        sorted_iperf_commands.each do |iperf_cmd|
          sorted_clients = iperf_cmd['clients'].sort_by { |client| client['client_node'] }
          iperf_cmd['clients'] = sorted_clients

          base_port_num = 5201
          iperf_cmd['clients'].each_with_index do |client, index|
            client['server_port'] = base_port_num + index
          end
        end
        sorted_iperf_commands
      end

      # @param [Array<Hash>] iperf_commands iPerf commands
      # @param [String] dst_node_name Destination node name
      # @return [nil, Hash] iPerf command which server_node is dst_node_name
      def find_iperf_cmd_by_node_name(iperf_commands, dst_node_name)
        iperf_commands.find { |iperf_cmd| iperf_cmd['server_node'] == dst_node_name }
      end

      # @param [Array<Hash>] flow_data Flow data
      # @param [Hash] l3endpoint_dict Layer3 endpoint data (single node)
      # @return [Hash] iPerf command
      def source_info(flow_data, l3endpoint_dict)
        {
          'client_node' => l3endpoint_dict[flow_data['source']]['node'],
          'server_address' => l3endpoint_dict[flow_data['dest']]['ip_addr'],
          'server_port' => 0, # define later
          'rate' => flow_data['rate'].to_f
        }
      end

      # rubocop:disable Metrics/MethodLength

      # @param [Hash] l3endpoint_dict Layer3 endpoint dictionary
      # @return [Array<Hash>] iperf commands iPerf commands
      def create_iperf_commands(l3endpoint_dict)
        iperf_commands = []
        @flow_data_list.each do |flow_data|
          dst_node_name = l3endpoint_dict[flow_data['dest']]['node']
          target_iperf_command = find_iperf_cmd_by_node_name(iperf_commands, dst_node_name)
          source_info = source_info(flow_data, l3endpoint_dict)

          if target_iperf_command.nil?
            iperf_commands.append({ 'server_node' => dst_node_name, 'clients' => [source_info] })
          else
            target_iperf_command['clients'].append(source_info)
          end
        end
        iperf_commands
      end
      # rubocop:enable Metrics/MethodLength

      # @param [Hash] l3endpoint L3 endpoint data (single node)
      # @return [String] ip address of a L3 endpoint data
      def ip_addr_from_l3endpoint(l3endpoint)
        # NOTE: endpoint has only one interface in pni usecase...
        l3endpoint['interfaces'][0]['attribute']['ip-address'][0].split('/')[0]
      end

      # @param [Hash] l3endpoint Layer3 endpoint data
      # @return [Hash]
      def extract_l3endpoint_data(l3endpoint)
        return { 'node' => nil, 'ip_addr' => nil } if l3endpoint.nil?

        { 'node' => l3endpoint['node'], 'ip_addr' => ip_addr_from_l3endpoint(l3endpoint) }
      end

      # @param [Hash] l3endpoint L3 endpoint data
      # return [Boolean] true if l3endpiont is in subnet_addr
      def l3endpoint_in_subnet?(l3endpoint, subnet_addr)
        l3endpoint_ip_str = ip_addr_from_l3endpoint(l3endpoint)
        l3endpoint_ip = IPAddr.new(l3endpoint_ip_str)
        subnet_ip = IPAddr.new(subnet_addr)
        subnet_ip.include?(l3endpoint_ip)
      end

      # @param [String] subnet_addr Subnet address of a flow data record
      # @return [Hash] L3 endpoint data in the subnet addr
      def find_l3endpoint_by_flow(subnet_addr)
        l3ep = @l3endpoint_list.find { |l3endpoint| l3endpoint_in_subnet?(l3endpoint, subnet_addr) }
        extract_l3endpoint_data(l3ep)
      end

      # return [Hash<Hash>] Layer3 endpoint dictionary
      def create_l3endpoint_dict
        # NOTE: There is one iperf endpoint for each source/destination subnet in the flow_data.
        l3endpoint_dict = {}
        @flow_data_list.each do |flow_data|
          %w[source dest].each do |flow_end|
            next unless l3endpoint_dict[flow_end].nil?

            l3endpoint_dict[flow_data[flow_end]] = find_l3endpoint_by_flow(flow_data[flow_end])
          end
        end
        # dictionary to convert from segment (flow data, source/dest) to l3endpoint node
        # {
        #   "10.0.1.0/24" => { "node" => "as65550-endpoint00", "ip_addr" => "10.0.1.100" },
        #   ...
        # }
        l3endpoint_dict
      end
    end
  end
end
