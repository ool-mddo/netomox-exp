# frozen_string_literal: true

require_relative 'topology_converter_base'

module TopologyOperator
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
      # NOTE: interface (tp) name is unsafe
      "#{safe_node_name(edge.node_ref)}:#{edge.tp_ref}"
    end

    # @return [Array<Hash>] link data
    def link_data
      links = unique_links
      links.map do |link|
        { 'endpoints' => [link_edge_to_str(link.source), link_edge_to_str(link.destination)] }
      end
    end

    # @param [String] image Container image name
    # @param [String] kind Container type
    # @param [String] config Startup-config file name
    # @return [Hash]
    def define_node_data(image, kind, config)
      {
        'image' => image,
        'kind' => kind,
        'startup-config' => config
      }
    end

    # @param [Netomox::Topology::Node] node
    # @return [Hash]
    # @raise [StandardError] if found unknown node-type
    def make_node_data(node)
      node_name = safe_node_name(node.name)
      case node.attribute.node_type
      when 'segment'
        define_node_data('ghcr.io/ool-mddo/clab-ovs:latest', 'linux', "#{node_name}.conf")
      when 'node', 'endpoint'
        define_node_data('crpd:22.1R1.10', 'juniper_crpd', "#{node_name}.conf")
      else
        raise StandardError, "Unknown node type: #{node.name}, type=#{node.attribute.node_type}"
      end
    end

    # @return [Hash<Hash>] node data
    def node_data
      @src_network.nodes.to_h { |node| [safe_node_name(node.name), make_node_data(node)] }
    end

    # @return [void]
    # @raise [StandardError] if specified source network is not layer3
    def check_network_type
      # NOTE: network type is iterable hash
      nw_type = @src_network.network_types.keys[0]

      raise StandardError, "Network:#{@src_network.name} is not layer3" if nw_type != Netomox::NWTYPE_MDDO_L3
    end
  end
end
