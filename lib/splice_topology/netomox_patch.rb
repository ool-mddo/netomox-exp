# frozen_string_literal: true

require 'netomox'

module Netomox
  module Topology
    # reopen base object class to add method
    class TopoObjectBase
      # @return [String] Parent object name
      def parent_name
        @parent_path.split('__').last
      end
    end

    # reopen node class to add meethod
    class Node < TopoObjectBase
      # @param [Node] node Node
      # @return [void]
      def append_support_by_node(node)
        support = SupportingNode.new(support_data_by_node(node))
        @supports.push(support)
      end

      private

      # @param [Node] node Node
      # @return [Hash] support data
      def support_data_by_node(node)
        paths = node.path.split('__')
        {
          'network-ref' => paths[0],
          'node-ref' => paths[1]
        }
      end
    end

    # reopen network class to add method
    class Network < TopoObjectBase
      # @param [TermPoint] src_tp Source term-point (link edge)
      # @param [TermPoint] dst_tp Destination term-point (link edge)
      # @return [void]
      def append_link_by_tp(src_tp, dst_tp)
        new_link = create_link(link_data_by_tp(src_tp, dst_tp))
        @links.push(new_link)
      end

      # @param [String] segment Segment string (ex: "a.b.c.d/xx")
      # @param [TermPoint] tp1 TermPoint1 (src)
      # @param [TermPoint] tp2 TermPoint2 (dst)
      # @return [Node]
      def append_segment_node(segment, tp1, tp2)
        segment_node = find_node_by_name(segment_node_name(segment))
        # return it if found (exists already)
        return segment_node if segment_node

        # return created segment node
        segment_node = create_node(segment_node_data(segment, tp1, tp2))
        @nodes.push(segment_node)
        segment_node
      end

      private

      # @param [String] segment Segment string (ex: "a.b.c.d/xx")
      # @return [String] segment node name
      def segment_node_name(segment)
        "Seg_#{segment}"
      end

      # @param [String] segment Segment string (ex: "a.b.c.d/xx")
      # @return [Hash] Segment node attribute data (RFC8345 Hash)
      def segment_node_attribute(segment)
        {
          'node-type' => 'segment',
          'prefix' => [{ 'prefix' => segment, 'metric' => 0, 'flag' => [] }]
        }
      end

      # @param [String] segment Segment string (ex: "a.b.c.d/xx")
      # @param [TermPoint] tp1 TermPoint1 (src)
      # @param [TermPoint] tp2 TermPoint2 (dst)
      # @return [Hash] Segment node data (RFC8345 Hash)
      def segment_node_data(segment, tp1, tp2)
        {
          'node-id' => segment_node_name(segment),
          "#{NS_MDDO}:l3-node-attributes" => segment_node_attribute(segment),
          "#{NS_TOPO}:termination-point" => [tp1, tp2].map { |tp| segment_tp_data_by_tp(tp) }
        }
      end

      # @param [TermPoint] term_point Term-point
      # @return [Hash] Segment term-point data (RFC8345 Hash)
      def segment_tp_data_by_tp(term_point)
        { 'tp-id' => "#{term_point.parent_name}_#{term_point.name}" }
      end

      # rubocop:disable Metrics/MethodLength
      # @param [TermPoint] src_tp Source term-point (link edge)
      # @param [TermPoint] dst_tp Destination term-point (link edge)
      # @return [Hash] Link data (RFC8345 Hash)
      def link_data_by_tp(src_tp, dst_tp)
        {
          'link-id' => [src_tp.parent_name, src_tp.name, dst_tp.parent_name, dst_tp.name].join(','),
          'source' => {
            'source-node' => src_tp.parent_name,
            'source-tp' => src_tp.name
          },
          'destination' => {
            'dest-node' => dst_tp.parent_name,
            'dest-tp' => dst_tp.name
          }
        }
      end
      # rubocop:enable Metrics/MethodLength
    end
  end
end
