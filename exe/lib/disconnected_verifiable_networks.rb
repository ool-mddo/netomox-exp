# frozen_string_literal: true

require 'netomox'
require 'forwardable'
require_relative './network_sets'

module Netomox
  module Topology
    # Networks with DisconnectedVerifiableNetwork
    class DisconnectedVerifiableNetworks < Networks
      # @return [NetworkSets] Found network sets
      def find_all_network_sets
        NetworkSets.new(@networks)
      end

      private

      # @overload
      def create_network(data)
        DisconnectedVerifiableNetwork.new(data)
      end
    end

    # Network class to find disconnected sub-graph
    class DisconnectedVerifiableNetwork < Network
      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize

      # Connected sub-graph(s)
      #   sub-graph = connected node and term-point paths list (set)
      #   return several sub-graphs when the network have disconnected networks (sub-graphs).
      # @return [Array<NetworkSubset>] List of connected node/term-point paths
      def find_all_subsets
        remove_deleted_state_elements!
        # Array<NetworkSubset>, NOTE: it may be NetworkSet
        subsets = []
        @nodes.each do |node|
          network_subset = NetworkSubset.new
          network_subset.push(node.path) # origin node

          # it assumes that a standalone node is a single subset.
          if node.termination_points.length.zero?
            subsets.push(network_subset)
            next
          end

          # if the node has link(s), search connected element recursively
          node.termination_points.each do |tp|
            next if subsets.find { |sub_graph| sub_graph.include?(tp.path) }

            find_connected_nodes_recursively(node, tp, network_subset)
            subsets.push(network_subset.uniq!)
          end
        end
        subsets
      end
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

      private

      # Remove node/tp, link which has "deleted" diff_state
      # @return [void]
      def remove_deleted_state_elements!
        @nodes.delete_if { |node| node.diff_state.detect == :deleted }
        @nodes.each do |node|
          node.termination_points.delete_if { |tp| tp.diff_state.detect == :deleted }
        end
        @links.delete_if { |link| link.diff_state.detect == :deleted }
      end

      # @param [Node] node (Source) Node
      # @param [TermPoint] term_point (Source) Term-point
      # @param [NetworkSubset] nw_subset Connected node and term-point paths (as sub-graph)
      # @return [void]
      def find_connected_nodes_recursively(node, term_point, nw_subset)
        nw_subset.push(term_point.path)
        link = find_link_by_source(node.name, term_point.name)
        return unless link

        dst_node = find_node_by_name(link.destination.node_ref)
        return unless dst_node

        nw_subset.push(node.path) # push node multiple times: need `uniq`
        dst_node.termination_points.each do |dst_tp|
          next if nw_subset.include?(dst_tp.path) # loop avoidance

          find_connected_nodes_recursively(dst_node, dst_tp, nw_subset)
        end
      end
    end
  end
end
