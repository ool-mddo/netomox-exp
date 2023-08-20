# frozen_string_literal: true

require_relative 'convert_table_base'

module NetomoxExp
  module NamespaceConvertTable
    # Term-point name in static-route convert table
    class StaticRouteTpTable < ConvertTableBase
      # @param [NodeNameTable] node_name_table
      def initialize(node_name_table)
        super()
        @node_name_table = node_name_table
      end

      # @param [String] src_node_name Source node name
      # @param [String] route_prefix Prefix of a static route entry
      # @param [String] route_tp Interface name of a static route entry
      # @raise [StandardError]
      def convert(src_node_name, route_prefix, route_tp)
        route_key = static_route_key(src_node_name, route_prefix)
        unless key?(route_key)
          raise StandardError, "Route #{route_key} in #{src_node_name} is not in static_route_tp_table"
        end

        unless key?(route_key, route_tp)
          raise StandardError,
                "Static route: #{route_tp} of route #{route_key} in #{src_node_name} is not in static_route_tp_table"
        end

        @convert_table[static_route_key(src_node_name, route_prefix)][route_tp]
      end

      # @param [String] route_key Keyword of a static route entry (node name & prefix)
      # @param [String] route_tp_name Interface name in a static route entry
      # return [Boolean] true if the static route is in static route table
      def key?(route_key, route_tp_name = nil)
        return @convert_table.key?(route_key) if route_tp_name.nil?

        @convert_table.key?(route_key) && @convert_table[route_key].key?(route_tp_name)
      end

      # @param [Netomox::Topology::Networks] src_nws Source networks
      # @return [void]
      def make_table(src_nws)
        super(src_nws)
        src_nw = @src_nws.find_network('layer3')
        src_nw.nodes.each do |src_node|
          src_node.attribute.static_routes.each { |route| add_static_route_entry(src_node, route) }
        end
      end

      private

      # @param [String] src_node Source node name
      # @param [String] route_prefix Prefix of a static route entry
      # @return [String] Key string to identify the route entry
      def static_route_key(src_node, route_prefix)
        "#{src_node}:#{route_prefix}"
      end

      # rubocop:disable Metrics/AbcSize

      # @param [Netomox::Topology::Node] src_node Source node (L3)
      # @param [Netomox::Topology::MddoL3StaticRoute] route Static route entry
      # @return [void]
      def add_static_route_entry(src_node, route)
        # forward
        # NOTE: As demonstration, all actual nodes (except segment node) in emulated environment
        #   are actualized using cRPD.
        #   Therefore, all interface of static route attribute will be 'dynamic'
        fwd_route_key = static_route_key(src_node.name, route.prefix)
        @convert_table[fwd_route_key] = {} unless key?(fwd_route_key)
        @convert_table[fwd_route_key][route.interface] = 'dynamic'
        # reverse
        bwd_route_key = static_route_key(@node_name_table.convert(src_node.name)['l3_model'], route.prefix)
        @convert_table[bwd_route_key] = {} unless key?(bwd_route_key)
        @convert_table[bwd_route_key]['dynamic'] = route.interface
      end
      # rubocop:enable Metrics/AbcSize
    end
  end
end
