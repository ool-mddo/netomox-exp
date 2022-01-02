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
      # rubocop:disable Metrics/MethodLength

      # Explore connected network elements (subsets)
      #   subset = connected node and term-point paths list (set)
      #   return several subsets when the network have disconnected networks.
      # @return [NetworkSet] Network-set (set of network-subsets, in a network(layer))
      def find_all_subsets
        remove_deleted_state_elements!
        network_set = NetworkSet.new(@name)
        @nodes.each do |node|
          network_subset = NetworkSubset.new(node.path) # origin node

          # it assumes that a standalone node is a single subset.
          if node.termination_points.length.zero?
            network_set.push(network_subset)
            next
          end

          # if the node has link(s), search connected element recursively
          node.termination_points.each do |tp|
            # explore origin selection:
            # if exists a subset includes the (source) term-point,
            # it should have already been explored.
            next if network_set.find_subset_includes(tp.path)

            find_connected_nodes_recursively(node, tp, network_subset)
            network_set.push(network_subset.uniq!)
          end
        end
        network_set
      end
      # rubocop:enable Metrics/MethodLength

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
