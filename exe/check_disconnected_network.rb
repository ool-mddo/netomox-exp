#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'netomox'
require 'json'

module Netomox
  module Topology
    # Networks with DisconnectedVerifiableNetwork
    class DisconnectedVerifiableNetworks < Networks
      # @return [Array<Hash>] Found disconnected sub-graphs
      def find_all_disconnected_sub_graphs
        @networks.map do |nw|
          {
            network: nw.name,
            sub_graphs: nw.find_sub_graphs
          }
        end
      end

      private

      # @overload
      def create_network(data)
        DisconnectedVerifiableNetwork.new(data)
      end
    end

    # Network class to find disconnected sub-graph
    class DisconnectedVerifiableNetwork < Network
      # rubocop:disable Metrics/MethodLength

      # @return [Array<Array<String>>] List of connected term-point paths (as sub-graph)
      def find_sub_graphs
        delete_objects_own_deleted_state
        sub_graphs = [] # Array<Array<String>> : list of connected-sub-graph
        @nodes.each do |node|
          connected_graphs = []
          node.termination_points.each do |tp|
            next if sub_graphs.find { |sub_graph| sub_graph.include?(tp.path) }

            find_connected_nodes_recursively(node, tp, connected_graphs)
            sub_graphs.push(connected_graphs)
          end
        end
        sub_graphs
      end
      # rubocop:enable Metrics/MethodLength

      private

      # Delete node/tp, link which has "deleted" diff_state
      #   Note: destructive method
      # @return [void]
      def delete_objects_own_deleted_state
        @nodes.delete_if { |node| node.diff_state.detect == :deleted }
        @nodes.each do |node|
          node.termination_points.delete_if { |tp| tp.diff_state.detect == :deleted }
        end
        @links.delete_if { |link| link.diff_state.detect == :deleted }
      end

      # @param [Node] node (Source) Node
      # @param [TermPoint] term_point (Source) Term-point
      # @param [Array<String>] connected_graphs Connected term-point paths (as sub-graph)
      # @return [void]
      def find_connected_nodes_recursively(node, term_point, connected_graphs)
        connected_graphs.push(term_point.path)
        link = find_link_by_source(node.name, term_point.name)
        return unless link

        dst_node = find_node_by_name(link.destination.node_ref)
        return unless dst_node

        dst_node.termination_points.each do |dst_tp|
          next if connected_graphs.include?(dst_tp.path) # loop avoidance

          find_connected_nodes_recursively(dst_node, dst_tp, connected_graphs)
        end
      end
    end
  end
end

## main

opts = ARGV.getopts('i:', 'input:')
input_file = opts['i'] || opts['input']
unless input_file
  warn 'Input file is not specified'
  exit 1
end

raw_topology_data = JSON.parse(File.read(input_file))
nws = Netomox::Topology::DisconnectedVerifiableNetworks.new(raw_topology_data)
sub_graphs = nws.find_all_disconnected_sub_graphs
puts JSON.pretty_generate(sub_graphs)

sub_graphs.each do |sg|
  if sg[:sub_graphs].size > 1
    warn "Network #{sg[:network]} has #{sg[:sub_graphs].size} disconnected sub-graphs"
  else
    warn "Network #{sg[:network]} is connected"
  end
end
