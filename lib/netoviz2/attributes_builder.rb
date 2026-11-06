# frozen_string_literal: true

require 'lib/netoviz2/diff_label'

module NetomoxExp
  module Netoviz2
    # Builder of the attributes response (attributes and diff details of the specified objects)
    #
    # Attributes are what netomox holds (`attribute.to_data`). They are not changed or completed here.
    class AttributesBuilder
      # Key of supports in RFC8345 data for each object type
      SUPPORTING_KEY = {
        layer: 'supporting-network', node: 'supporting-node',
        tp: 'supporting-termination-point', link: 'supporting-link'
      }.freeze

      # @param [Model] model Model
      def initialize(model)
        @model = model
      end

      # @param [Array<String>] ids Object IDs
      # @return [Hash]
      def build(ids)
        objects = {}
        not_found = []
        ids.uniq.each do |id|
          entry = @model.entry(id)
          entry ? objects[id] = object_data(entry) : not_found << id
        end
        { objects:, not_found: }
      end

      private

      def object_data(entry)
        object = entry.object
        data = { type: entry.type.to_s, attributes: attributes_of(object) }
        supporting = supporting_of(entry.type, object)
        data[:supporting] = supporting unless supporting.empty?
        diff_state = diff_state_of(object)
        data[:diff_state] = diff_state if diff_state
        data
      end

      # @return [Hash] `{ "mddo-topology:...-attributes" => {...} }` (empty if no attribute)
      def attributes_of(object)
        attr = object.attribute
        attr.empty? ? {} : { attr.type => attr.to_data }
      end

      def supporting_of(type, object)
        object.supports.empty? ? {} : { SUPPORTING_KEY.fetch(type) => object.supports.map(&:to_data) }
      end

      # @return [Hash,nil] diff state (nil if the object is kept without diff details)
      def diff_state_of(object)
        state = object.diff_state
        return nil if DiffLabel.of(object).nil? && (state.diff_data.nil? || state.diff_data.empty?)

        state.to_data
      end
    end
  end
end
