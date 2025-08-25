# frozen_string_literal: true

require 'netomox'

module NetomoxExp
  module UsecaseDeliverer
    # Layer3 preallocated (empty) resource builder for manual_steps usecase
    class Layer3PreallocatedResourceBuilder
      # @param [String] usecase Usecase name
      # @param [Hash] usecase_params Params data
      def initialize(usecase, usecase_params)
        @usecase_name = usecase
        @preallocated_resources = usecase_params['l3_preallocated_resources']

        # initialize layer3 preallocated-resources topology
        @topology = Netomox::PseudoDSL::PNetworks.new
        @layer3_nw = @topology.network('layer3')
        @layer3_nw.type = Netomox::NWTYPE_MDDO_L3
        @layer3_nw.attribute = { name: 'mddo-layer3-network' }

        # make preallocated resources
        make_layer3_preallocated_resources
      end

      # @return [Hash] preallocated L3-resource data (rfc8345)
      def build_topology
        @topology.interpret.topo_data
      end

      private

      # @param [Netomox::PseudoDSL::PNode] l3_node Layer3 node
      # param [String] tp_name Term-point name to add (default="", then set automatically, for shutdown-bridge)
      # @return [Network::PseudoDSL::PTermPoint] new interface
      def add_interface_to_node(l3_node, tp_name = nil)
        tp_name = "sbp#{l3_node.tps.length}" if tp_name.nil?

        l3_tp = l3_node.term_point(tp_name)
        l3_tp.attribute = { flags: %w[preallocated-tp] }
        l3_tp
      end

      # rubocop:disable Metrics/AbcSize

      # @param [Hash] prealloc_node_data Defs of a preallocated L3-node
      # @param [Netomox::PseudoDSL::PNode] sb_node Shutdown-bridge node
      # @return [void]
      def add_layer3_preallocated_node(prealloc_node_data, sb_node)
        l3e_node = @layer3_nw.node(prealloc_node_data['name'])
        l3e_node.attribute = { node_type: 'node', flags: %w[preallocated-node] }

        # interfaces
        prealloc_node_data['interfaces'].each do |ifname|
          l3e_tp = add_interface_to_node(l3e_node, ifname)

          # connect the interface to shutdown-bridge
          sb_tp = add_interface_to_node(sb_node)
          @layer3_nw.link(l3e_node.name, l3e_tp.name, sb_node.name, sb_tp.name)
          @layer3_nw.link(sb_node.name, sb_tp.name, l3e_node.name, l3e_tp.name)
        end
      end
      # rubocop:enable Metrics/AbcSize

      # @param [Hash] prealloc_segment_data Defs of a preallocated L3-segment-node
      # @return [void]
      def add_layer3_preallocated_segment(prealloc_segment_data)
        l3e_seg_node = @layer3_nw.node(prealloc_segment_data['name'])
        l3e_seg_node.attribute = { node_type: 'segment', flags: %w[preallocated-segment] }
      end

      # @return [Netomox::PseudoDSL::PNode] shutdown bridge node
      def add_layer3_shutdown_bridge
        sb_node = @layer3_nw.node('Seg_empty00')
        sb_node.attribute = { node_type: 'segment', flags: %w[empty-segment] }
        sb_node
      end

      # @raise StandardError Invalid preallocated resource defs
      def make_layer3_preallocated_resources
        sb_node = add_layer3_shutdown_bridge
        @preallocated_resources.each do |prealloc_resources|
          if prealloc_resources['type'] == 'node'
            add_layer3_preallocated_node(prealloc_resources, sb_node)
          elsif prealloc_resources['type'] == 'segment'
            add_layer3_preallocated_segment(prealloc_resources)
          else
            raise StandardError, "Unknown type #{prealloc_resources['type']} in usecase #{@usecase_name} params"
          end
        end
      end
    end
  end
end
