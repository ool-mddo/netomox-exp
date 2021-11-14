# frozen_string_literal: true

# base class for pseudo network object
class PObjectBase
  # @!attribute [rw] name
  #   @return [String]
  # @!attribute [rw] attribute
  #   @return [Hash]
  # @!attribute [rw] supports
  #   @return [Array<(String, Array<String>)>]
  #   @note `[nw_name,..]` for network,
  #     `[[nw_name, node_name],..]` for node,
  #     `[[nw_name, node_name, tp_name],...]` for tp
  attr_accessor :name, :attribute, :supports

  # @param [String] name Name of the object
  def initialize(name)
    @name = name
    @attribute = nil
    @supports = []
  end
end

# pseudo network
class PNetwork < PObjectBase
  # @!attribute [rw] nodes
  #   @return [Array<PNode>]
  # @!attribute [rw] links
  #   @return [Array<PLink>]
  # @!attribute [rw] type
  #   @return [String]
  attr_accessor :nodes, :links, :type

  # @param [String] name Name of the network
  def initialize(name)
    super(name)
    @type = nil # Hash
    @nodes = [] # Array<PNode>
    @links = [] # Array<PLink>
  end

  # print to stdout
  def dump
    warn "network: #{name}"
    warn '  nodes:'
    @nodes.each { |n| warn "    - #{n}" }
    warn '  links:'
    @links.each { |l| warn "    - #{l}" }
  end

  # Find or create new node
  # @param [String] node_name Name of the node
  # @return [PNode] Found or added node
  def node(node_name)
    found_node = find_node_by_name(node_name)
    return found_node if found_node

    new_node = PNode.new(node_name)
    @nodes.push(new_node)
    new_node
  end

  # Find or create link
  # @param [String] src_node_name Source node name
  # @param [String] src_tp_name Source term-point name (on source node)
  # @param [String] dst_node_name Destination node name
  # @param [String] dst_tp_name Destination term-point name (on destination node)
  # @return [PLink] Found or added link
  def link(src_node_name, src_tp_name, dst_node_name, dst_tp_name)
    found_link = find_link_by_src_dst_name(src_node_name, src_tp_name, dst_node_name, dst_tp_name)
    return found_link if found_link

    src = PLinkEdge.new(src_node_name, src_tp_name)
    dst = PLinkEdge.new(dst_node_name, dst_tp_name)
    new_link = PLink.new(src, dst)
    @links.push(new_link)
    new_link
  end

  # @param [String] node_name Node name to find
  # @return [nil, PNode] Node if found or nil if not found
  def find_node_by_name(node_name)
    @nodes.find { |node| node.name == node_name }
  end

  # @param [PLinkEdge] edge Source link-edge
  # @@return [nil, PLink] Link if found or  nil if not found
  def find_link_by_src_edge(edge)
    find_link_by_src_name(edge.node, edge.tp)
  end

  # @param [String] node_name Source node name
  # @param [String] tp_name destination node name (on source node)
  # @return [nil, PLink] Link if found or nil if not found
  def find_link_by_src_name(node_name, tp_name)
    @links.find do |link|
      link.src.node == node_name && link.src.tp == tp_name
    end
  end

  # @param [PLinkEdge] edge Link-edge to find
  # @return [nil, PTermPoint] Term-point if found or nil if not found
  def find_tp_by_edge(edge)
    node = find_node_by_name(edge.node)
    return unless node

    node.find_tp_by_name(edge.tp)
  end

  # @param [String] node1 Source node name
  # @param [String] tp1 Source term-point name (on source node)
  # @param [String] node2 Destination node name
  # @param [String] tp2 Destination term-point name (on destination node)
  # @return [nil, PLink] Link if found or nil if not found
  def find_link_by_src_dst_name(node1, tp1, node2, tp2)
    @links.find do |link|
      link.src.node == node1 && link.src.tp == tp1 &&
        link.dst.node == node2 && link.dst.tp == tp2
    end
  end
end

# pseudo node
class PNode < PObjectBase
  # @!attribute [rw] tps
  #   @return [Array<PTermPoint>]
  attr_accessor :tps

  # @param [String] name Name of the network
  def initialize(name)
    super(name)
    @tps = [] # Array<PTermPoint>
  end

  # Generate term-point name automatically
  # @return [String] term-point name
  def auto_tp_name
    tp_names = @tps.map(&:name).filter { |name| name =~ /p\d+/ }
    tp_name_numbers = tp_names.map do |name|
      name =~ /p(\d+)/
      Regexp.last_match(1).to_i
    end.sort
    next_number = tp_name_numbers.length.positive? ? tp_name_numbers.pop + 1 : 1
    "p#{next_number}"
  end

  # Find or create new term-point
  # @param [String] tp_name Name of the term-point
  # @return [PTermPoint] Found or added term-point
  def term_point(tp_name)
    found_tp = find_tp_by_name(tp_name)
    return found_tp if found_tp

    new_tp = PTermPoint.new(tp_name)
    @tps.push(new_tp)
    new_tp
  end

  # @param [String] tp_name Term-point name to find
  # @return [nil, PTermPoint] Term-point if found or nil if not found
  def find_tp_by_name(tp_name)
    @tps.find { |tp| tp.name == tp_name }
  end

  # @param [String] tp_name Term-point name to omit
  # @return [Array<PTermPoint>] Array of term-point without the term-point
  def tps_without(tp_name)
    @tps.reject { |tp| tp.name == tp_name }
  end

  # @return [String] String
  def to_s
    name.to_s
  end
end

# pseudo termination point
class PTermPoint < PObjectBase
  # @return [String] String
  def to_s
    "[#{name}]"
  end
end

# base class for pseudo link
class PLinkEdge
  # @!attribute [rw] node
  #   @return [String]
  # @!attribute [rw] tp
  #   @return [String]
  attr_accessor :node, :tp

  # @param [String] node_name Node name
  # @param [String] tp_name Term-point name (on the node)
  def initialize(node_name, tp_name)
    @node = node_name
    @tp = tp_name
  end

  # @return [Boolean] true if equal
  def ==(other)
    @node == other.node && @tp == other.tp
  end

  # @return [String] String
  def to_s
    "#{node}[#{tp}]"
  end
end

# pseudo link
class PLink
  # @!attribute [rw] src
  #   @return [PLinkEdge]
  # @!attribute [rw] dst
  #   @return [PLinkEdge]
  attr_accessor :src, :dst

  # @param [PLinkEdge] src Source link-edge
  # @param [PLinkEdge] dst Destination link-edge
  def initialize(src, dst)
    @src = src
    @dst = dst
  end

  # @return [String]
  def to_s
    "#{src} > #{dst}"
  end
end
