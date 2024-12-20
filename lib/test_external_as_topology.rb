# frozen_string_literal: true

require 'netomox'
require 'optparse'
require 'json'
require 'yaml'
require 'csv'
require_relative 'netomox_exp'
require_relative 'usecase_deliverer/external_as_topology/bgp_as_data_builder'

module NetomoxExp
  # rubocop:disable Metrics/ModuleLength

  # namespace for testing scripts
  module TestTools
    USECASE_DIR = ENV['USECASE_DIR'] || "#{__dir__}/../../../usecases" # playground/usecases
    TOPOLOGY_DIR = ENV['TOPOLOGY_DIR'] || "#{__dir__}/../../../topologies" # playground/topologies

    module_function

    # helpers

    def read_json_file(file_path)
      JSON.parse(File.read(file_path))
    end

    def read_yaml_file(file_path)
      YAML.load_file(file_path)
    end

    def read_csv_file(file_path)
      csv_data = CSV.read(file_path, headers: true)
      csv_data.map(&:to_h)
    end

    def read_flow_data(usecase, network, flow_file)
      flow_file_path = File.join(USECASE_DIR, usecase, network, 'flows', "#{flow_file}.csv")
      read_csv_file(flow_file_path)
    end

    def read_params(usecase, network)
      param_file_path = File.join(USECASE_DIR, usecase, network, 'params.yaml')
      read_yaml_file(param_file_path)
    end

    def read_topology_object(network, snapshot)
      topology_file_path = File.join(TOPOLOGY_DIR, network, snapshot, 'topology.json')
      topology_data = read_json_file(topology_file_path)
      Netomox::Topology::Networks.new(topology_data)
    end

    # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/AbcSize, Metrics/MethodLength
    def merge_ext_topology(layers, src_builders, dst_builder)
      # whole networks
      ext_as_topology = Netomox::PseudoDSL::PNetworks.new
      # merge
      layers.each do |layer|
        if layer == 'layer3'
          ext_as_layer = ext_as_topology.network(layer)
          src_layers = src_builders.map(&:layer3_nw)
          dst_layer = dst_builder.layer3_nw
          ext_as_layer.type = Netomox::NWTYPE_MDDO_L3
          ext_as_layer.attribute = { name: 'mddo-layer3-network' }
          ext_as_layer.nodes = [src_layers.map(&:nodes), dst_layer.nodes].flatten
          ext_as_layer.links = [src_layers.map(&:links), dst_layer.links].flatten
        elsif layer == 'bgp_proc'
          ext_as_layer = ext_as_topology.network(layer)
          src_layers = src_builders.map(&:bgp_proc_nw)
          dst_layer = dst_builder.bgp_proc_nw
          ext_as_layer.type = Netomox::NWTYPE_MDDO_BGP_PROC
          ext_as_layer.attribute = { name: 'mddo-bgp-network' }
          ext_as_layer.nodes = [src_layers.map(&:nodes), dst_layer.nodes].flatten
          ext_as_layer.links = [src_layers.map(&:links), dst_layer.links].flatten
        end
      end

      ext_as_topology.interpret.topo_data
    end
    # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/AbcSize, Metrics/MethodLength

    # rubocop:disable Metrics/MethodLength
    def l3_src_as_builders(usecase, usecase_params, usecase_flows, int_as_topology)
      if usecase_params.key?('source_as')
        [
          NetomoxExp::UsecaseDeliverer::Layer3DataBuilder.new(usecase, :source_as, usecase_params['source_as'],
                                                              usecase_flows, int_as_topology, 0)
        ]
      elsif usecase_params.key?('source_ases')
        usecase_params['source_ases'].map.with_index do |as_param, ipam_seed|
          NetomoxExp::UsecaseDeliverer::Layer3DataBuilder.new(usecase, :source_as, as_param,
                                                              usecase_flows, int_as_topology, ipam_seed)
        end
      else
        warn "ERROR: invalid usecase params: #{usecase_params}"
        exit 1
      end
    end
    # rubocop:enable Metrics/MethodLength

    def l3_dst_as_builders(usecase, usecase_params, usecase_flows, int_as_topology)
      ipam_seed = dst_as_builders_ipam_seed(usecase_params)
      NetomoxExp::UsecaseDeliverer::Layer3DataBuilder.new(usecase, :dest_as, usecase_params['dest_as'],
                                                          usecase_flows, int_as_topology, ipam_seed)
    end

    def dst_as_builders_ipam_seed(usecase_params)
      if usecase_params.key?('source_as')
        1 # source_as = 0, dest_as = 1
      elsif usecase_params.key?('source_ases')
        usecase_params['source_ases'].length # source_as = 0...length-1, dest_as = length
      else
        warn "ERROR: invalid usecase params: #{usecase_params}"
      end
    end

    # rubocop:disable Metrics/MethodLength
    def bgp_proc_src_as_builders(usecase, usecase_params, usecase_flows, int_as_topology)
      if usecase_params.key?('source_as')
        [
          NetomoxExp::UsecaseDeliverer::BgpProcDataBuilder.new(usecase, :source_as, usecase_params['source_as'],
                                                               usecase_flows, int_as_topology, 0)
        ]
      elsif usecase_params.key?('source_ases')
        usecase_params['source_ases'].map.with_index do |as_param, ipam_seed|
          NetomoxExp::UsecaseDeliverer::BgpProcDataBuilder.new(usecase, :source_as, as_param,
                                                               usecase_flows, int_as_topology, ipam_seed)
        end
      else
        warn "ERROR: invalid usecase params: #{usecase_params}"
        exit 1
      end
    end
    # rubocop:enable Metrics/MethodLength

    def bgp_proc_dst_as_builders(usecase, usecase_params, usecase_flows, int_as_topology)
      ipam_seed = dst_as_builders_ipam_seed(usecase_params)
      NetomoxExp::UsecaseDeliverer::BgpProcDataBuilder.new(usecase, :dest_as, usecase_params['dest_as'],
                                                           usecase_flows, int_as_topology, ipam_seed)
    end

    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    def main
      # option definitions

      options = {}
      opt_parser = OptionParser.new do |opts|
        opts.banner = "Usage: #{$PROGRAM_NAME} [options]"
        opts.on('-n', '--network NETWORK', 'Network (required)') do |network|
          options[:network] = network
        end
        opts.on('-s', '--snapshot SNAPSHOT', 'Snapshot (required)') do |snapshot|
          options[:snapshot] = snapshot
        end
        opts.on('-u', '--usecase USECASE', 'Usecase (required)') do |usecase|
          options[:usecase] = usecase
        end
        opts.on('-l', '--layer LAYER', 'Layer (optional)') do |layer|
          options[:layer] = layer
        end
      end

      opt_parser.parse!

      %i[network snapshot usecase].each do |key|
        next unless options[key].nil?

        puts "Error: #{key} is required"
        puts opt_parser
        exit 1
      end

      # debug
      network, snapshot, usecase = %i[network snapshot usecase].map { |key| options[key] }
      warn "Network: #{network}"
      warn "Snapshot: #{snapshot}"
      warn "Usecase: #{usecase}"

      # read files
      usecase_params = read_params(usecase, network)
      usecase_flows = read_flow_data(usecase, network, 'event')
      int_as_topology = read_topology_object(network, snapshot)

      # build ext-as topology data
      if options[:layer] == 'layer3'
        # debug layer3
        src_topo_builders = l3_src_as_builders(usecase, usecase_params, usecase_flows, int_as_topology)
        dst_topo_builder = l3_dst_as_builders(usecase, usecase_params, usecase_flows, int_as_topology)
        puts JSON.generate(merge_ext_topology(%w[layer3], src_topo_builders, dst_topo_builder))
      elsif options[:layer] == 'bgp_proc'
        # debug bgp_proc (includes layer3)
        src_topo_builders = bgp_proc_src_as_builders(usecase, usecase_params, usecase_flows, int_as_topology)
        dst_topo_builder = bgp_proc_dst_as_builders(usecase, usecase_params, usecase_flows, int_as_topology)
        puts JSON.generate(merge_ext_topology(%w[bgp_proc layer3], src_topo_builders, dst_topo_builder))
      else
        # default
        # debug bgp-as (includes bgp-proc, layer3)
        builder = NetomoxExp::UsecaseDeliverer::BgpAsDataBuilder.new(usecase, usecase_params, usecase_flows,
                                                                     int_as_topology)
        puts JSON.generate(builder.build_topology)
      end
    rescue OptionParser::InvalidOption, OptionParser::MissingArgument => e
      warn e.message
      exit 1
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize
  end
  # rubocop:enable Metrics/ModuleLength
end

NetomoxExp::TestTools.main
