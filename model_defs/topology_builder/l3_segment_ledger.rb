# frozen_string_literal: true

require 'forwardable'

module TopologyBuilder
  # L3 segment data holder
  class L3SegmentLedger
    extend Forwardable
    # @!method push
    #   @see Array#size
    # @!method each
    #   @see Array#each
    # @!method each_with_index
    #   @see Array#each_with_index
    # @!method to_s
    #   @see Array#to_s
    # @!method find_all
    #   @see Array#to_s
    # @!method map
    #   @see Array#to_s
    def_delegators :@segments, :push, :each, :each_with_index, :to_s, :find_all, :map

    def initialize
      @segments = [] # Array(Array(PLinkEdge))
    end

    # @param [PLinkEdge] edge Link-edge
    # @return [Boolean] true if there is a segment includes the link-edge
    def exist_segment_includes?(edge)
      @segments.each do |seg|
        return true if seg.include?(edge)
      end
      false
    end

    # @return [Array<PLinkEdge>] Appended link-edge array
    def append_new_segment
      seg = [] # Array<PlinkEdge>
      @segments.push(seg)
      seg
    end

    # Remove empty segment (empty array) from segments
    # @return [void]
    def clean!
      @segments.reject!(&:empty?)
    end

    # @return [Array<PLinkEdge>] current segment to push link-edge
    def current_segment
      @segments[-1]
    end

    # print stderr
    # @return [void]
    def dump
      @segments.each_with_index do |seg, i|
        warn "# segment: #{i}"
        seg.each do |edge|
          warn "  - #{edge.node}, #{edge.tp}"
        end
      end
    end
  end
end
