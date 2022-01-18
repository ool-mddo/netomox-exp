# frozen_string_literal: true

module TopologyOperator
  # Network subset: connected network elements (node/tp) in a network (layer)
  class NetworkSubset
    # @!attribute [r] elements
    #   return [Array<String>]
    attr_reader :elements
    # @!attribute [rw] flag
    #   @return [Hash]
    attr_accessor :flag

    # @param [Array<String>] element_paths Paths of node/term-point
    def initialize(*element_paths)
      @elements = element_paths || []
      @flag = {}
    end

    # @return [NetworkSubset] self
    def uniq!
      @elements.uniq!
      self
    end

    # @return [Hash]
    def to_data
      { elements: @elements, flag: @flag }
    end
  end
end
