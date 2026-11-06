# frozen_string_literal: true

require 'erb'

module NetomoxExp
  module Netoviz2
    # Object ID of netoviz2 view-model (see docs/netoviz2_data_format.md in playground)
    #
    # node-id/tp-id/link-id may contain `/` and `,` (e.g. `Seg_172.32.0.0/30`, `ge-0/0/0.0`),
    # so each segment is percent-encoded and joined with `/`.
    # Only `A-Z a-z 0-9 _ . -` are kept (`~` is also encoded, because `~` is used as the marker below).
    #
    #   layer: <network>               node: <network>/<node>
    #   tp:    <network>/<node>/<tp>   link: <network>/~link/<link-id>
    #
    # A link ID has the marker `~link` which never equals an encoded segment, so IDs of different types
    # never collide. An ID is an opaque string for clients. It is stable for the same topology data.
    module ObjectId
      # Marker segment of link IDs
      LINK_MARKER = '~link'

      module_function

      # @param [String] network Network (layer) name
      # @return [String]
      def layer(network)
        segment(network)
      end

      # @param [String] network Network (layer) name
      # @param [String] node Node name
      # @return [String]
      def node(network, node)
        join(network, node)
      end

      # @param [String] network Network (layer) name
      # @param [String] node Node name
      # @param [String] term_point Term-point name
      # @return [String]
      def tp(network, node, term_point)
        join(network, node, term_point)
      end

      # @param [String] network Network (layer) name
      # @param [String] link Link name (whole link-id is one segment)
      # @return [String]
      def link(network, link)
        [segment(network), LINK_MARKER, segment(link)].join('/')
      end

      # @param [String] name A path element
      # @return [String]
      def segment(name)
        ERB::Util.url_encode(name.to_s).gsub('~', '%7E')
      end

      # @param [Array<String>] names Path elements
      # @return [String]
      def join(*names)
        names.map { |name| segment(name) }.join('/')
      end
    end
  end
end
