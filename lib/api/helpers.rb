# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'netomox'
require 'lib/convert_namespace/namespace_converter'

module NetomoxExp
  # helpers for NetomoxRestApi
  module Helpers
    # @param [String] file_path File path to read
    # @return [Object]
    def read_json_file(file_path)
      error!("Not found: topology file: #{file_path}", 404) unless File.exist?(file_path)

      JSON.parse(File.read(file_path))
    end

    # @param [String] file_path File path to save
    # @param [void]
    def save_json_file(file_path, data)
      logger.warn "[save_json_file] path=#{file_path}"
      FileUtils.mkdir_p(File.dirname(file_path))
      File.open(file_path, 'w') { |file| JSON.dump(data, file) }
    end

    # @param [String] network Network name
    # @param [String] snapshot Snapshot name
    # @return [Object] Networks data
    def read_topology_file(network, snapshot)
      topology_file = File.join(TOPOLOGIES_DIR, network, snapshot, 'topology.json')
      read_json_file(topology_file)
    end

    # @param [String] network Network name
    # @param [String] snapshot Snapshot name
    # @return [Netomox::Topology::Networks] topology instance
    def read_topology_instance(network, snapshot)
      topology_data = read_topology_file(network, snapshot)
      Netomox::Topology::Networks.new(topology_data)
    end

    # @param [String] network Network name
    # @return [String] file path
    def ns_convert_table_file(network)
      File.join(TOPOLOGIES_DIR, network, 'ns_convert_table.json')
    end

    # @param [String] network Network name
    # @return [void]
    def save_ns_convert_table(network, data)
      save_json_file(ns_convert_table_file(network), data)
    end

    # @param [String] network Network name
    # @return [Hash] convert_table
    def read_ns_convert_table(network)
      read_json_file(ns_convert_table_file(network))
    end

    # @param [String] network Network name
    # @return [NamespaceConverter] Namespace converter without topology data
    def ns_converter_wo_topology(network)
      ns_converter = NamespaceConverter.new
      ns_converter.reload_convert_table(read_ns_convert_table(network))
      ns_converter
    end

    # @param [String, Symbol] layer_type Network layer type keyword
    # @return [String, nil] Strict layer type string (nil = unknown type)
    def convert_layer_type(layer_type)
      layer_type_table = {
        layer1: Netomox::NWTYPE_MDDO_L1,
        layer2: Netomox::NWTYPE_MDDO_L2,
        layer3: Netomox::NWTYPE_MDDO_L3,
        ospf: Netomox::NWTYPE_MDDO_OSPF_AREA
      }
      layer_type_table[layer_type.intern]
    end

    # @param [NamespaceConverter] ns_converter Namespace converter (without topology data)
    # @param [Netomox::Topology::Node] node Node
    # @return [Hash]
    def _node_hash(ns_converter, node)
      {
        node: node.name,
        reverse: ns_converter.node_name_table.reverse_lookup(node.name),
        alias: ns_converter.node_name_table.find_l1_alias(node.name),
        attribute: node.attribute.to_data
      }
    end

    # @param [String] network Network name (target of namespace conversion)
    # @param [Array<Netomox::Topology::Node>] nodes Nodes in a layer
    # @return [Array<Hash>] Node/interfaces objects in the layer
    def convert_layer_nodes(network, nodes)
      ns_converter = ns_converter_wo_topology(network)
      nodes.map { |node| _node_hash(ns_converter, node) }
    end

    # @param [NamespaceConverter] ns_converter Namespace converter (without topology data)
    # @param [Netomox::Topology::Node] node Node
    # @param [Netomox::Topology::TermPoint] term_point Termination point
    # @return [Hash]
    def _interfaces_hash(ns_converter, node, term_point)
      {
        interface: term_point.name,
        reverse: ns_converter.tp_name_table.reverse_lookup(node.name, term_point.name)[1],
        alias: ns_converter.tp_name_table.find_l1_alias(node.name, term_point.name),
        attribute: term_point.attribute.to_data
      }
    end

    # @param [String] network Network name (target of namespace conversion)
    # @param [Array<Netomox::Topology::Node>] nodes Nodes in a layer
    # @return [Array<Hash>] Node/interfaces objects in the layer
    def convert_layer_interfaces(network, nodes)
      ns_converter = ns_converter_wo_topology(network)
      nodes.map do |node|
        node_hash = _node_hash(ns_converter, node)
        node_hash[:interfaces] = node.termination_points.map { |tp| _interfaces_hash(ns_converter, node, tp) }
        node_hash
      end
    end
  end
end
