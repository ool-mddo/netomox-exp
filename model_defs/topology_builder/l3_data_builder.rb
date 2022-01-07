# frozen_string_literal: true

require_relative 'l3_data_checker'
require_relative 'csv_mapper/ip_owners_table'
require_relative 'csv_mapper/interface_prop_table'
require 'ipaddress'

# rubocop:disable Metrics/ClassLength

module TopologyBuilder
  # L3 data builder
  class L3DataBuilder < L3DataChecker
    # @param [String] target Target network (config) data name
    # @param [PNetwork] layer2p Layer2 network topology
    def initialize(target:, layer2p:, debug: false)
      super(layer2p: layer2p, debug: debug)
      @ip_owners = CSVMapper::IPOwnersTable.new(target)
      @intf_props = CSVMapper::InterfacePropertiesTable.new(target)
      # NOTE: use object_id for hash key
      #   e.g. `@segment_prefixes[seg]` means `@segment_prefixes[seg.object_id]`
      #   ref. https://www.rubydoc.info/gems/rubocop/RuboCop/Cop/Lint/HashCompareByIdentity
      @segment_prefixes = {}.compare_by_identity
    end

    # @return [PNetworks] Networks contains only layer3 network topology
    def make_networks
      @network = @networks.network('layer3')
      @network.type = Netomox::NWTYPE_MDDO_L3
      explore_l3_segment
      setup_segment_to_prefixes_table
      add_l3_node_tp_link
      update_node_attribute
      @networks
    end

    private

    # @param [IPOwnersTableRecord] rec A record of IP-Owners table
    # @return [String] Name of layer3 node
    def l3_node_name(rec)
      rec.vrf == 'default' ? rec.node : "#{rec.node}_#{rec.vrf}"
    end

    # @param [IPOwnersTableRecord] rec A record of IP-Owners table
    # @param [PNode] l2_node A layer2 node
    # @return [PNode] Added layer3 node
    def add_l3_node(rec, l2_node)
      node_name = l3_node_name(rec)
      l3_node = @network.node(node_name)
      l3_node.supports.push([@layer2p.name, l2_node.name])
      l3_node.attribute = {
        node_type: node_name =~ /.*svr\d+/i ? 'endpoint' : 'node'
      }
      l3_node
    end

    # @param [IPOwnersTableRecord] rec A record of IP-Owners table
    # @param [PNode] l3_node layer3 node to add term-point
    # @param [PLinkEdge] l2_edge A Link-edge in layer2 topology (in segment)
    # @return [PTermPoint] Added layer3 term-point
    def add_l3_tp(rec, l3_node, l2_edge)
      l3_tp = l3_node.term_point(rec.interface)
      l3_tp.supports.push([@layer2p.name, l2_edge.node, l2_edge.tp])
      tp_prop = @intf_props.find_record_by_node_intf(rec.node, rec.interface)
      l3_tp.attribute = {
        ip_addrs: ["#{rec.ip}/#{rec.mask}"],
        description: tp_prop ? tp_prop.description : ''
      }
      l3_tp
    end

    # @param [PLinkEdge] l2_edge Layer2 link edge
    # @return [Array(IPOwnersTableRecord, PNode)] L3 (IPOwners) record and corresponding L2 node
    def ip_rec_by_l2_edge(l2_edge)
      l2_node = @layer2p.node(l2_edge.node)
      rec = @ip_owners.find_record_by_node_intf(l2_node.attribute[:name], l2_edge.tp)

      # if rec not found, search virtual node (GRT/VRF)
      rec ||= @ip_owners.find_vlan_intf_record_by_node(l2_node.attribute[:name], l2_node.attribute[:vlan_id])
      # debug_print "  l2_edge=#{l2_edge}, rec=#{rec}"

      [rec, l2_node]
    end

    # @param [PLinkEdge] l2_edge A Link-edge in layer2 topology (in segment)
    # @return [Array<(PNode, PTermPoint)>] Added L3-Node and term-point pair
    def add_l3_node_tp(l2_edge)
      rec, l2_node = ip_rec_by_l2_edge(l2_edge)

      return [nil, nil] unless rec

      l3_node = add_l3_node(rec, l2_node)
      l3_tp = add_l3_tp(rec, l3_node, l2_edge)
      [l3_node, l3_tp]
    end

    # @param [PNode] l3_seg_node Layer3 segment-node
    # @param [PLink] l2_link Layer2 link
    # @param [PNode] l3_node Layer3 node
    # @param [PTermPoint] l3_tp Layer3 term-point
    # @return [String] Term-point name
    def l3_seg_tp_name(l3_seg_node, l2_link, l3_node, l3_tp)
      l2_dst_node = @layer2p.node(l2_link.dst.node)
      tp_name = l2_link ? "#{l2_dst_node.attribute[:name]}_#{l2_link.dst.tp}" : l3_seg_node.auto_tp_name
      tp_name = "#{l3_node.name}_#{l3_tp.name}" if l3_tp.name =~ /Vlan\d+/
      tp_name
    end

    # rubocop:disable Metrics/AbcSize

    # Connect L3 segment-node and host-node
    # @param [PNode] l3_seg_node Layer3 segment-node
    # @param [PNode] l3_node Layer3 (host) node
    # @param [PTermPoint] l3_tp Layer3 (host) port on l3_node
    # @param [PLinkEdge] l2_edge A Link-edge in layer2 topology (in segment)
    # @return [void]
    def add_l3_link(l3_seg_node, l3_node, l3_tp, l2_edge)
      l2_link = @layer2p.find_link_by_src_edge(l2_edge)
      l3_seg_tp = l3_seg_node.term_point(l3_seg_tp_name(l3_seg_node, l2_link, l3_node, l3_tp))
      l3_seg_tp.supports.push([@layer2p.name, l2_link.dst.node, l2_link.dst.tp])
      debug_print "  link: #{l3_seg_node.name}, #{l3_seg_tp.name}, #{l3_node.name}, #{l3_tp.name}"
      @network.link(l3_seg_node.name, l3_seg_tp.name, l3_node.name, l3_tp.name)
      @network.link(l3_node.name, l3_tp.name, l3_seg_node.name, l3_seg_tp.name) # bidirectional
    end
    # rubocop:enable Metrics/AbcSize

    # @param [Array<PLinkEdge>] segment Edge list in same segment
    # @return [Array<Hash>] A list of 'prefix' attribute
    def collect_segment_prefixes(segment)
      prefixes = segment.map do |l2_edge|
        rec, = ip_rec_by_l2_edge(l2_edge)
        # debug_print "  prefix in Segment: #{l2_edge}] -> #{rec}"
        rec && IPAddress::IPv4.new("#{rec.ip}/#{rec.mask}")
      end
      warn '# WARNING: L2 closed segment?'
      prefixes.compact.map { |ip| "#{ip.network}/#{ip.prefix}" }.uniq.map do |prefix|
        { prefix: prefix, metric: 0 } # metric = 0 : default metric of connected route
      end
    end

    # pre calculation to decrease amount of calculation
    # @return [Hash<Integer, Array>] segment object_id to prefixes hash
    def setup_segment_to_prefixes_table
      @segments.each { |seg| @segment_prefixes[seg] = collect_segment_prefixes(seg) }
    end

    # @param [Array<PLinkEdge>] segment Edge list in same segment
    # @return [String] Segment node suffix string
    def segment_node_suffix(segment)
      prefixes = @segment_prefixes[segment]
      prefixes.length.positive? ? "_#{prefixes[0][:prefix]}" : ''
    end

    # @param [Array<PLinkEdge>] segment Edge list in same segment
    # @return [Integer] -1 if unique prefix segment, >=0 index number of same prefix segment
    def index_of_same_prefix_segment(segment)
      seg_node_suffix = segment_node_suffix(segment)
      # find segments that will be same name segment-node
      # NOTE: identify its segments with its object-id (see also: `@segment_prefixes`)
      same_prefix_segment_ids = @segments.find_all { |seg| seg_node_suffix == segment_node_suffix(seg) }
                                         .map(&:object_id)
                                         .sort # fix its position in array
      debug_print "* target: #{segment.object_id}, list: #{same_prefix_segment_ids}"
      # NOT found other segments owns same node suffix
      #   always find target `segment` itself (position 0) -> return -1
      #   unnecessary to use index number for segment node
      # Found multiple segments owns same node suffix -> return position(index, >0) of the segment in array.
      same_prefix_segment_ids.length <= 1 ? -1 : same_prefix_segment_ids.index(segment.object_id)
    end

    # @param [Array<PLinkEdge>] segment Edge list in same segment
    # @return [String] Layer3 segment node name
    def segment_node_name(segment)
      seg_index = index_of_same_prefix_segment(segment)
      seg_suffix = segment_node_suffix(segment)
      seg_index.negative? ? "Seg#{seg_suffix}" : "Seg#{seg_suffix}##{seg_index}"
    end

    # @param [Array<PLinkEdge>] segment Edge list in same segment
    # @return [PNode] Layer3 segment node
    def add_l3_seg_node(segment)
      # NOTICE: countermeasure of ip address block duplication
      #   If there are segments which are different but have same network prefix,
      #   Identify its segments with index number.
      l3_seg_node = @network.node(segment_node_name(segment))
      l3_seg_node.attribute = { prefixes: @segment_prefixes[segment], node_type: 'segment' }
      l3_seg_node
    end

    # rubocop:disable Metrics/MethodLength

    # Add all layer3 node, tp and link
    # @return [void]
    def add_l3_node_tp_link
      @segments.each_with_index do |segment, i|
        # segment: Array(PLinkEdge)
        debug_print("# Segment#{i}: suffix = #{segment_node_suffix(segment)}")
        l3_seg_node = add_l3_seg_node(segment)
        segment.each do |l2_edge|
          l3_seg_node.supports.push([@layer2p.name, l2_edge.node])
          l3_node, l3_tp = add_l3_node_tp(l2_edge)
          if l3_node.nil? || l3_tp.nil?
            warn "# WARNING: Can not link (it seems L2 link): #{l3_seg_node.name} > #{l2_edge}"
            next
          end

          add_l3_link(l3_seg_node, l3_node, l3_tp, l2_edge)
        end
      end
    end
    # rubocop:enable Metrics/MethodLength

    # @return [Array<PNode>] Found nodes
    def find_all_node_type_nodes
      @network.nodes.filter { |n| n.attribute[:node_type] == 'node' }
    end

    # @param [PNode] l3_node Layer3 node
    # @return [Array<PTermPoint>] Found term-points
    def find_all_l3_tps_has_ipaddr(l3_node)
      l3_node.tps.filter { |tp| tp.attribute[:ip_addrs]&.length&.positive? }
    end

    # @param [PNode] l3_node Layer3 node
    # @return [Array<Hash>] A list of layer3 node prefix (directly connected routes)
    def node_prefixes_at_l3_node(l3_node)
      find_all_l3_tps_has_ipaddr(l3_node).map do |tp|
        ip = IPAddress::IPv4.new(tp.attribute[:ip_addrs][0])
        { prefix: "#{ip.network}/#{ip.prefix}", metric: 0, flags: %w[directly-connected] }
      end
    end

    # Set layer3 node attribute (prefixes) according to its term-point
    # @return [void]
    def update_node_attribute
      debug_print '# update node attribute'
      find_all_node_type_nodes.each do |l3_node|
        prefixes = node_prefixes_at_l3_node(l3_node)
        debug_print "- node: #{l3_node.name}, prefixes: #{prefixes}"
        l3_node.attribute[:prefixes] = prefixes
      end
    end
  end

  # rubocop:enable Metrics/ClassLength
end
