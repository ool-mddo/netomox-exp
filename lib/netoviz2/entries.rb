# frozen_string_literal: true

module NetomoxExp
  module Netoviz2
    # Any object of the topology that can be selected by ID (`type` is :layer, :node, :tp or :link)
    Entry = Struct.new(:type, :layer_id, :object)
    # Layer (network) with the objects in it
    LayerEntry = Struct.new(:id, :network, :nodes, :links)
    NodeEntry = Struct.new(:id, :node, :tps)
    TpEntry = Struct.new(:id, :node_id, :tp)
    LinkEntry = Struct.new(:id, :link, :src_id, :dst_id)
    # Support between objects of different (or same) layers. `from` is the supported (upper) object.
    SupportEdge = Struct.new(:kind, :from, :to)
  end
end
