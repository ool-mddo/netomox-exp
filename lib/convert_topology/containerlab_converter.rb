# frozen_string_literal: true

require_relative 'topology_converter_base'

module NetomoxExp
  module ConvertTopology
    # topology data converter for container-lab
    class ContainerLabConverter < TopologyConverterBase
      # @return [Hash] topology data for clab
      def convert
        check_network_type
        {
          'name' => @options[:env_name] || 'emulated',
          'topology' => {
            'links' => link_data,
            'nodes' => node_data
          }
        }
      end

      private

      # integrate bidirectional link pair as one link
      # @return [Array<Netomox::Topology::Link>] unique links
      def unique_links
        links = []
        @src_network.links.each do |link|
          rev_link = links.find { |l| l.source == link.destination && l.destination == link.source }
          links.push(link) unless rev_link
        end
        links
      end

      # @param [Netomox::Topology::TpRef] edge Link edge
      # @return [String]
      def link_edge_to_str(edge)
        node_name = converted_node_l1principal(edge.node_ref)
        tp_name = converted_tp_l1principal(edge.node_ref, edge.tp_ref)
        "#{node_name}:#{tp_name}"
      end

      # @return [Array<Hash>] link data
      def link_data
        links = unique_links
        links.map do |link|
          { 'endpoints' => [link_edge_to_str(link.source), link_edge_to_str(link.destination)] }
        end
      end

      # @param [String] kind Container type
      # param [Hash] opts Options for clab-topo.yaml
      # @return [Hash]
      def define_node_data(kind, opts = {})
        data = { 'kind' => kind }
        %w[image type startup-config license binds components].each do |key|
          # NOTE
          #   binds: Array<String>
          #   components: Hash
          data[key] = opts[key] if opts.key?(key) && !(opts[key].nil? || opts[key].empty?)
        end
        data
      end

      # @param [String] node_name Node name
      # @return [Hash, nil] nil if not found
      def find_l3prealloc_node(node_name)
        return nil unless @options.key?(:usecase_l3preallocs)

        node_params = @options[:usecase_l3preallocs].find { |n| n['type'] == 'node' && n['name'] == node_name }
        return nil if node_params.nil? || !node_params.key?('emulated_params')

        node_params['emulated_params'] # for clab-topo
      end

      # rubocop:disable Metrics/AbcSize, Metrics/MethodLength

      # @param [Netomox::Topology::Node] node
      # @return [Hash] clab-topo node data
      def select_node_data(node)
        l3_prealloc_params = find_l3prealloc_node(node.name)
        if node.attribute.flags.include?('preallocated_node') || l3_prealloc_params.nil?
          opts = { 'image' => @options[:image], 'startup-config' => "#{node.name}.conf" }
          opts['binds'] = [@options[:bind_license]] if @options.key?(:bind_license)
          opts['license'] = @options[:license] if @options.key?(:license)
          return define_node_data('juniper_crpd', opts)
        end

        # NOTE: for special empty resources (nokia sr-sim, that has node-params definitions in usecase params file)
        opts = {}
        %w[license image kind type components].each do |key|
          opts[key] = l3_prealloc_params[key] if l3_prealloc_params.key?(key)
        end
        define_node_data(l3_prealloc_params['kind'], opts)
      end
      # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

      # rubocop:disable Metrics/MethodLength

      # @param [Netomox::Topology::Node] node
      # @return [Hash]
      # @raise [StandardError] if found unknown node-type
      def make_node_data(node)
        converted_node_l1principal(node.name)
        case node.attribute.node_type
        when 'segment'
          define_node_data('ovs-bridge')
        when 'node'
          select_node_data(node)
        when 'endpoint'
          ep_image = @options[:endpoint_image] || 'ghcr.io/ool-mddo/ool-iperf:main'
          define_node_data('linux', { 'image' => ep_image })
        else
          raise StandardError, "Unknown node type: #{node.name}, type=#{node.attribute.node_type}"
        end
      end
      # rubocop:enable Metrics/MethodLength

      # @return [Hash<Hash>] node data
      def node_data
        @src_network.nodes.to_h { |node| [converted_node_l1principal(node.name), make_node_data(node)] }
      end

      # @return [void]
      # @raise [StandardError] if specified source network is not layer3
      def check_network_type
        # NOTE: network type is iterable hash
        nw_type = @src_network.primary_network_type

        raise StandardError, "Network:#{@src_network.name} is not layer3" if nw_type != Netomox::NWTYPE_MDDO_L3
      end
    end
  end
end
