# frozen_string_literal: true

require 'netomox'

module NetomoxExp
  module UsecaseDeliverer
    # Layer3 empty resource builder for manual_steps usecase
    class Layer3EmptyResourceBuilder
      # @param [String] usecase Usecase name
      # @param [Hash] usecase_params Params data
      def initialize(usecase, usecase_params)
        @usecase_name = usecase
        @empty_resources = usecase_params['empty_l3_resources']

        # initialize layer3 empty-resources topology
        @topology = Netomox::PseudoDSL::PNetworks.new
        @layer3_nw = @topology.network('layer3')
        @layer3_nw.type = Netomox::NWTYPE_MDDO_L3
        @layer3_nw.attribute = { name: 'mddo-layer3-network' }

        # make empty resources
        make_layer3_empty_resources
      end

      # @return [Hash] empty L3-resource data (rfc8345)
      def build_topology
        @topology.interpret.topo_data
      end

      private

      # @param [Netomox::PseudoDSL::PNode] l3_node Layer3 node
      # param [String] tp_name Term-point name to add (defualt="", then set automatically, for shutdown-bridge)
      # @return [Network::PseudoDSL::PTermPoint] new interface
      def add_interface_to_node(l3_node, tp_name = nil)
        tp_name = "sbp#{l3_node.tps.length}" if tp_name.nil?

        l3_tp = l3_node.term_point(tp_name)
        l3_tp.attribute = { flags: %w[empty-tp] }
        l3_tp
      end

      # rubocop:disable Metrics/AbcSize

      # @param [Hash] empty_node_data Defs of a empty L3-node
      # @param [Netomox::PseudoDSL::PNode] sb_node Shutdown-bridge node
      # @return [void]
      def add_layer3_empty_node(empty_node_data, sb_node)
        l3e_node = @layer3_nw.node(empty_node_data['name'])
        l3e_node.attribute = { node_type: 'node', flags: %w[empty-node] }

        # interfaces
        empty_node_data['interfaces'].each do |ifname|
          l3e_tp = add_interface_to_node(l3e_node, ifname)

          # connect the interface to shutdown-bridge
          sb_tp = add_interface_to_node(sb_node)
          @layer3_nw.link(l3e_node.name, l3e_tp.name, sb_node.name, sb_tp.name)
          @layer3_nw.link(sb_node.name, sb_tp.name, l3e_node.name, l3e_tp.name)
        end
      end
      # rubocop:enable Metrics/AbcSize

      # @param [Hash] empty_segment_data Defs of a empty L3-segment-node
      # @return [void]
      def add_layer3_empty_segment(empty_segment_data)
        l3e_seg_node = @layer3_nw.node(empty_segment_data['name'])
        l3e_seg_node.attribute = { node_type: 'segment', flags: %w[empty-segment] }
      end

      # @return [Netomox::PseudoDSL::PNode] shutdown bridge node
      def add_layer3_shutdown_bridge
        sb_node = @layer3_nw.node('Seg_empty00')
        sb_node.attribute = { node_type: 'segment', flags: %w[empty-segment] }
        sb_node
      end

      # @raise StandardError Invalid empty resource defs
      def make_layer3_empty_resources
        sb_node = add_layer3_shutdown_bridge
        @empty_resources.each do |empty_resource|
          if empty_resource['type'] == 'node'
            add_layer3_empty_node(empty_resource, sb_node)
          elsif empty_resource['type'] == 'segment'
            add_layer3_empty_segment(empty_resource)
          else
            raise StandardError, "Unknown type #{empty_resource['type']} in usecase #{@usecase_name} params"
          end
        end
      end
    end
  end
end
