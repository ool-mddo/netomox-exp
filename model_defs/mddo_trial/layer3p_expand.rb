# frozen_string_literal: true

require_relative '../bf_common/pseudo_model'

# Expanded L3 data builder
class ExpandedL3DataBuilder < DataBuilderBase
  # @param [String] target Target network (config) data name
  # @param [PNetwork] layer3p Layer3 network topology
  def initialize(target:, layer3p:, debug: false)
    super(debug: debug)
    @layer3p = layer3p
  end

  # @return [PNetworks] Networks contains only layer3 network topology
  def make_networks
    @network = PNetwork.new('layer3exp')
    @network.type = Netomox::NWTYPE_L3
    expand_segment_to_p2p

    @networks.push(@network)
    @networks
  end

  private

  def find_all_segment_nodes
    @layer3p.nodes.find_all do |node|
      # TODO: node type detection
      node.name =~ /Seg\d+/
    end
  end

  def find_all_edges_connected(src_node)
    @layer3p.links
            .find_all { |link| link.src.node == src_node.name }
            .map { |link| link.dst }
  end

  def add_node(orig_l3_node)
    # copy except tps
    new_src_node = @network.node(orig_l3_node.name)
    new_src_node.supports = orig_l3_node.supports
    new_src_node.attribute = orig_l3_node.attribute
    new_src_node
  end

  def add_tp(index, src_node, orig_l3_tp)
    # copy with indexed-name
    new_tp = src_node.term_point(orig_l3_tp.name + "##{index}")
    new_tp.supports = orig_l3_tp.supports
    new_tp.attribute = orig_l3_tp.attribute
    new_tp
  end

  def add_node_tp_links(seg_connected_edges)
    seg_connected_edges.each_with_index do |src_edge, si|
      src_node = @layer3p.find_node_by_name(src_edge.node)
      src_tp = src_node.find_tp_by_name(src_edge.tp)
      new_src_node = add_node(src_node)

      seg_connected_edges.each_with_index do |dst_edge, di|
        next if dst_edge == src_edge

        dst_node = @layer3p.find_node_by_name(dst_edge.node)
        dst_tp = dst_node.find_tp_by_name(dst_edge.tp)

        new_src_tp = add_tp(di, new_src_node, src_tp)
        new_dst_node = add_node(dst_node)
        new_dst_tp = add_tp(si, new_dst_node, dst_tp)
        debug_print "link: #{new_src_node.name}, #{new_src_tp.name}, #{new_dst_node.name}, #{new_dst_tp.name}"
        @network.link(new_src_node.name, new_src_tp.name, new_dst_node.name, new_dst_tp.name)
      end
    end
  end

  def expand_segment_to_p2p
    segment_nodes = find_all_segment_nodes
    debug_print "seg nodes = #{segment_nodes.map(&:name)}"
    segment_nodes.each do |seg_node|
      seg_connected_edges = find_all_edges_connected(seg_node)
      debug_print "seg edges = #{seg_connected_edges.map(&:to_s)}"
      add_node_tp_links(seg_connected_edges)
    end
  end
end
