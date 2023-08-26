# frozen_string_literal: true

require_relative 'topology_converter_base'

module NetomoxExp
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
    # @param [String] image Container image name
    # @param [String] config Startup-config file name
    # @param [Array<String>] bind_configs
    # @return [Hash]
    def define_node_data(kind, image: nil, config: nil, bind_configs: [])
      data = { 'kind' => kind }
      data['image'] = image unless image.nil?
      data['startup-config'] = config unless config.nil?
      data['binds'] = bind_configs unless bind_configs.empty?
      data
    end

    # @param [Netomox::Topology::Node] node
    # @return [Hash]
    # @raise [StandardError] if found unknown node-type
    def make_node_data(node)
      node_name = converted_node_l1principal(node.name)
      case node.attribute.node_type
      when 'segment'
        define_node_data('ovs-bridge')
      when 'node', 'endpoint'
        define_node_data('juniper_crpd', image: 'crpd:22.1R1.10', config: "#{node_name}.conf",
                                         bind_configs: [@options[:bind_license]])
      else
        raise StandardError, "Unknown node type: #{node.name}, type=#{node.attribute.node_type}"
      end
    end

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
