# frozen_string_literal: true

require 'netomox'
require 'forwardable'
require_relative './network_sets'
require_relative './network_set'
require_relative './network_subsets'

module Netomox
  module Topology
    # Networks with DisconnectedVerifiableNetwork
    class DisconnectedVerifiableNetworks < Networks
      # @return [TopologyOperator::NetworkSets] Found network sets
      def find_all_network_sets
        TopologyOperator::NetworkSets.new(@networks)
      end

      private

      # override
      def create_network(data)
        DisconnectedVerifiableNetwork.new(data)
      end
    end

    # Network class to find disconnected sub-graph
    class DisconnectedVerifiableNetwork < Network
      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize

      # Explore connected network elements (subsets)
      #   subset = connected node and term-point paths list (set)
      #   return several subsets when the network have disconnected networks.
      # @return [TopologyOperator::NetworkSet] Network-set (set of network-subsets, in a network(layer))
      def find_all_subsets
        remove_deleted_state_elements!
        network_set = TopologyOperator::NetworkSet.new(@name)

        # select entry point for recursive-network-search
        @nodes.each do |node|
          # if the node doesn't have any interface,
          # it assumes that a standalone node is a single subset.
          if node.termination_points.length.zero?
            network_set.push(TopologyOperator::NetworkSubset.new(node.path))
            next
          end

          # if the node has link(s), search connected element recursively
          network_subset = TopologyOperator::NetworkSubset.new
          node.termination_points.each do |tp|
            # explore origin selection:
            # if exists a subset includes the (source) term-point,
            # it should have already been explored.
            next if network_set.find_subset_includes(tp.path)

            find_connected_nodes_recursively(node, tp, network_subset)
          end
          network_set.push(network_subset.uniq!)
        end
        network_set.reject_empty_set!
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

      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

      # @param [Node] src_node (Source) Node
      # @param [TermPoint] src_tp (Source) Term-point
      # @param [NetworkSubset] nw_subset Connected node and term-point paths (as sub-graph)
      # @return [void]
      def find_connected_nodes_recursively(src_node, src_tp, nw_subset)
        nw_subset.push(src_node.path, src_tp.path)
        link = find_link_by_source(src_node.name, src_tp.name)
        return unless link

        dst_node = find_node_by_name(link.destination.node_ref)
        return unless dst_node

        dst_tp = dst_node.find_tp_by_name(link.destination.tp_ref)
        return unless dst_tp

        # node is pushed multiple times: need `uniq`
        nw_subset.push(dst_node.path, dst_tp.path)

        # stop recursive search if  destination node is endpoint node
        return if @name =~ /layer3/i && dst_node.attribute.node_type == 'endpoint'

        # select term-point and search recursively setting the destination node/tp as source
        dst_node.termination_points.each do |next_src_tp|
          # ignore dst_tp itself
          next if next_src_tp.name == dst_tp.name

          # loop detection
          if nw_subset.include?(next_src_tp.path)
            nw_subset.flag[:loop] = true
            next
          end

          find_connected_nodes_recursively(dst_node, next_src_tp, nw_subset)
        end
      end
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    end
  end
end
