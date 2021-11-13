# frozen_string_literal: true

require 'json'
require_relative '../bf_common/pseudo_model'

# L3 segment data holder
class L3SegmentLedger
  extend Forwardable
  def_delegators :@segments, :push, :to_s

  def initialize
    @segments = [] # Array(Array(PLinkEdge))
  end

  # arg: edge [PLinkEdge]
  def exist_segment_includes?(edge)
    @segments.each do |seg|
      return true if seg.include?(edge)
    end
    false
  end

  def append_new_segment
    seg = [] # Array(PlinkEdge)
    @segments.push(seg)
    seg
  end

  def clean!
    @segments.reject!(&:empty?)
  end

  def current_segment
    @segments[-1]
  end

  def current_segment_include?(edge)
    current_segment.include?(edge)
  end
end

# L2 data builder
class L3DataBuilder < DataBuilderBase
  def initialize(target, layer2p)
    super()
    @layer2p = layer2p
  end

  def make_networks
    @network = PNetwork.new('layer3')
    explore_l3_segment

    @network.nodes = @nodes
    @network.links = @links
    @networks.push(@network)
    @networks
  end

  private

  def recursively_explore_l3_segment(src_edge)
    @segments.current_segment.push(src_edge)
    src_node = @layer2p.find_node_by_name(src_edge.node)

    src_node.tps_without(src_edge.tp).each do |src_tp|
      src_edge = PLinkEdge.new(src_node.name, src_tp.name)
      link = @layer2p.find_link_by_src_edge(src_edge)
      next if !link || @segments.current_segment_include?(link.dst) # loop avoidance

      @segments.current_segment.push(src_edge)
      recursively_explore_l3_segment(link.dst)
    end
  end

  def explore_l3_segment
    @segments = L3SegmentLedger.new
    @layer2p.nodes.each do |src_node|
      @segments.append_new_segment
      src_node.tps.each do |src_tp|
        src_edge = PLinkEdge.new(src_node.name, src_tp.name)
        next if @segments.exist_segment_includes?(src_edge)

        link = @layer2p.find_link_by_src_edge(src_edge)
        next unless link

        @segments.current_segment.push(src_edge)
        recursively_explore_l3_segment(link.dst)
      end
    end
    @segments.clean!
    pp '# [L3] segment_members:', @segments
  end
end
