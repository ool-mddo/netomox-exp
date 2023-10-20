# frozen_string_literal: true

require_relative 'l3_data_checker'
require_relative 'csv_mapper/ip_owners_table'
require_relative 'csv_mapper/interface_prop_table'
require_relative 'csv_mapper/routes_table'
require 'ipaddress'

# rubocop:disable Metrics/ClassLength

module NetomoxExp
  module TopologyBuilder
    # L3 data builder
    class L3DataBuilder < L3DataChecker
      # @param [String] target Target network (config) data name
      # @param [Netomox::PseudoDSL::PNetwork] layer2p Layer2 network topology
      def initialize(target:, layer2p:, debug: false)
        super(layer2p:, debug:)
        @ip_owners = CSVMapper::IPOwnersTable.new(target)
        @intf_props = CSVMapper::InterfacePropertiesTable.new(target)
        @routes = CSVMapper::RoutesTable.new(target)
        # NOTE: use object_id for hash key
        #   e.g. `@segment_prefixes[seg]` means `@segment_prefixes[seg.object_id]`
        #   ref. https://www.rubydoc.info/gems/rubocop/RuboCop/Cop/Lint/HashCompareByIdentity
        @segment_prefixes = {}.compare_by_identity
      end

      # rubocop:disable Metrics/MethodLength

      # @return [Netomox::PseudoDSL::PNetworks] Networks contains only layer3 network topology
      def make_networks
        @network = @networks.network('layer3')
        @network.type = Netomox::NWTYPE_MDDO_L3
        @network.attribute = { name: 'mddo-layer3-network' }
        @network.supports.push(@layer2p.name)
        explore_l3_segment
        setup_segment_to_prefixes_table
        add_l3_node_tp_link
        add_l3_loopback_tps
        update_node_attribute
        add_unlinked_ip_owner_tp
        @networks
      end
      # rubocop:enable Metrics/MethodLength

      private

      # @param [IPOwnersTableRecord] rec A record of IP-Owners table
      # @return [String] Name of layer3 node
      def l3_node_name(rec)
        rec.grt? ? rec.node : "#{rec.node}_#{rec.vrf}"
      end

      # @param [IPOwnersTableRecord] rec A record of IP-Owners table
      # @param [Netomox::PseudoDSL::PNode] l2_node A layer2 node
      # @return [Netomox::PseudoDSL::PNode] Added layer3 node
      def add_l3_node(rec, l2_node)
        node_name = l3_node_name(rec)
        l3_node = @network.node(node_name)
        l3_node.supports.push([@layer2p.name, l2_node.name])
        l3_node.attribute = {} unless l3_node.attribute
        # TODO: ad-hoc node type detection...
        l3_node.attribute[:node_type] = node_name =~ /.*svr\d+/i ? 'endpoint' : 'node'
        l3_node.attribute[:flags] = ["vrf:#{rec.vrf}"] unless rec.grt?
        l3_node
      end

      # @param [IPOwnersTableRecord] rec A record of IP-Owners table
      # @param [Netomox::PseudoDSL::PNode] l3_node layer3 node to add term-point
      # @param [String] l2_node_name Layer2 node name (support node of a new term-point)
      # @param [String] l2_tp_name Layer2 term-point name (support tp of a new term-point)
      # @return [Netomox::PseudoDSL::PTermPoint] Added layer3 term-point
      def add_l3_tp(rec, l3_node, l2_node_name, l2_tp_name)
        l3_tp = l3_node.term_point(rec.interface)
        l3_tp.supports.push([@layer2p.name, l2_node_name, l2_tp_name])
        tp_prop = @intf_props.find_record_by_node_intf(rec.node, rec.interface)
        l3_tp.attribute = {
          ip_addrs: ["#{rec.ip}/#{rec.mask}"],
          description: tp_prop ? tp_prop.description : ''
        }
        l3_tp
      end

      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize

      # @param [Netomox::PseudoDSL::PNode] l2_node Layer2 node
      # @param [String] l2_tp_name Node name in the l2_node
      # @return [Array(CSVMapper::IPOwnersTableRecord, Netomox::PseudoDSL::PNode)]
      #   L3 (IPOwners) record and corresponding L2 node
      #   NOTE: it will return nil as IPOwnersTableRecord if ip-owner record is not found
      def ip_rec_by_l2_node(l2_node, l2_tp_name)
        # aliases
        l1_node_name = l2_node.attribute[:name]
        l2_vid = l2_node.attribute[:vlan_id]

        # if "l1_node_name[l2_tp_name]" interface has ip address
        debug_print "    ip_rec_by_l2_node, #{l2_node.name}, vid#{l2_vid} -> #{l1_node_name}, #{l2_tp_name}"
        ip_owner_rec = @ip_owners.find_record_by_node_intf(l1_node_name, l2_tp_name)

        # if rec not found, search virtual node (GRT/VRF)
        ip_owner_rec ||= @ip_owners.find_vlan_intf_record_by_node(l1_node_name, l2_vid)

        # if rec not found, search LAG parent
        intf_prop_rec = @intf_props.find_record_by_node_intf(l1_node_name, l2_tp_name)
        if intf_prop_rec&.lag_member?
          lag_parent_name = intf_prop_rec.lag_parent_interface
          debug_print "    LAG member: parent=#{l1_node_name}[#{lag_parent_name}]"
          # if parent has ip
          # - cisco, PoX
          # - junos, aeX (without unit number)
          ip_owner_rec ||= @ip_owners.find_record_by_node_intf(l1_node_name, lag_parent_name)
          # if (the node is junos and) unit interface has ip
          # NOTE:
          # in interface-props table
          #   (junos node)[aeX]     <parent> -> LAG members: [ge-X/Y,...]
          #   (junos node)[ge-X/Y]  <member> -> LAG group: [aeX]
          # in ip-owners table
          #   (junos node)[aeX.P] ... unit number is independent with LAG
          #   currently, .0 or vlan-id is used as unit number...but that is local naming policy
          ip_owner_rec ||= @ip_owners.find_record_by_node_intf(l1_node_name, "#{lag_parent_name}.#{l2_vid}")
          ip_owner_rec ||= @ip_owners.find_record_by_node_intf(l1_node_name, "#{lag_parent_name}.0")
        end

        debug_print "    ip_rec_by_node rec=#{ip_owner_rec}"
        [ip_owner_rec, l2_node]
      end
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

      # @param [Netomox::PseudoDSL::PLinkEdge] l2_edge Layer2 link edge
      # @return [Array(CSVMapper::IPOwnersTableRecord, Netomox::PseudoDSL::PNode)]
      #   L3 (IPOwners) record and corresponding L2 node
      def ip_rec_by_l2_edge(l2_edge)
        l2_node = @layer2p.node(l2_edge.node)
        ip_rec_by_l2_node(l2_node, l2_edge.tp)
      end

      # rubocop:disable Metrics/AbcSize

      # @param [Netomox::PseudoDSL::PNode] l2_node Layer2 node
      # @param [Netomox::PseudoDSL::PTermPoint] l2_tp Layer2 term-point
      # @return [Array(Netomox::PseudoDSL::PNode, Netomox::PseudoDSL::PTermPoint)] Added L3-Node and term-point pair
      # @raise StandardError if corresponding ip-owner term-point is not found for the unlinked-tp.
      #   Because in L1, topology-builder insert term-points that is not linked but owns ip-address.
      #   So, in L3, it must be found corresponding ip-owner tp info of unlinked term-point.
      def add_l3_node_tp_by_l2_node_tp(l2_node, l2_tp)
        rec, l2_node = ip_rec_by_l2_node(l2_node, l2_tp.name)
        debug_print "  - add_l3_node_tp: l2=#{l2_node.name}[#{l2_tp.name}], rec=#{rec}, l2_node=#{l2_node}"

        # ignore it for linked tp (L2 linked tp)
        return [nil, nil] if linked_l2_tp?(l2_node, l2_tp) && rec.nil?

        if !linked_l2_tp?(l2_node, l2_tp) && rec.nil?
          # raise error for unlinked tp
          @logger.error "Corresponding ip-owner interface is not found: #{l2_node.name}[#{l2_tp.name}]"
          return [nil, nil]
        end

        l3_node = add_l3_node(rec, l2_node)
        l3_tp = add_l3_tp(rec, l3_node, l2_node.name, l2_tp.name)
        [l3_node, l3_tp]
      end
      # rubocop:enable Metrics/AbcSize

      # @param [Netomox::PseudoDSL::PNode] l3_seg_node Layer3 segment-node (L3/src)
      # @param [Netomox::PseudoDSL::PLink] l2_link Layer2 link (l2, node -> seg_node)
      # @param [Netomox::PseudoDSL::PNode] l3_node Layer3 node (L3/dst)
      # @param [Netomox::PseudoDSL::PTermPoint] l3_tp Layer3 term-point (L2/dst)
      # @return [String] Term-point name
      def l3_seg_tp_name(l3_seg_node, l2_link, l3_node, l3_tp)
        l2_node = @layer2p.node(l2_link.src.node) # facing node of segment node
        tp_name = l2_link ? "#{l2_node.attribute[:name]}_#{l2_link.src.tp}" : l3_seg_node.auto_tp_name
        tp_name = "#{l3_node.name}_#{l3_tp.name}" if l3_tp.name =~ /Vlan\d+/
        tp_name
      end

      # @param [Netomox::PseudoDSL::PNode] l3_seg_node Layer3 segment-node (L3/src)
      # @param [Netomox::PseudoDSL::PNode] l3_node Layer3 (host) node (L3/dst)
      # @param [Netomox::PseudoDSL::PTermPoint] l3_tp Layer3 (host) port on l3_node (L3/dst)
      # @param [Netomox::PseudoDSL::PLinkEdge] l2_edge A Link-edge in layer2 topology (in segment) (L2/dst)
      # @return [Netomox::PseudoDSL::PTermPoint] L3/src interface (segment node term-point)
      def add_l3_seg_tp(l3_seg_node, l3_node, l3_tp, l2_edge)
        l2_link = @layer2p.find_link_by_src_edge(l2_edge) # link: (L2)node -> segment
        # L3/src term-point (segment node term-point)
        l3_seg_tp_name = l3_seg_tp_name(l3_seg_node, l2_link, l3_node, l3_tp)
        l3_seg_tp = l3_seg_node.term_point(l3_seg_tp_name)
        l3_seg_tp.supports.push([@layer2p.name, l2_link.dst.node, l2_link.dst.tp])
        l3_seg_tp.attribute = { description: "to_#{l3_node.name}_#{l3_tp.name}" }
        debug_print "    - seg-node-tp: #{l3_seg_tp.name}, attr=#{l3_seg_tp.attribute}"
        l3_seg_tp
      end

      # Connect L3 segment-node and host-node
      # @param [Netomox::PseudoDSL::PNode] l3_seg_node Layer3 segment-node (L3/src)
      # @param [Netomox::PseudoDSL::PTermPoint] l3_seg_tp Layer3 segment-node term point (L3/src)
      # @param [Netomox::PseudoDSL::PNode] l3_node Layer3 (host) node (L3/dst)
      # @param [Netomox::PseudoDSL::PTermPoint] l3_tp Layer3 (host) port on l3_node (L3/dst)
      # @return [void]
      def add_l3_link(l3_seg_node, l3_seg_tp, l3_node, l3_tp)
        debug_print "    - link: #{l3_seg_node.name}, #{l3_seg_tp.name}, #{l3_node.name}, #{l3_tp.name}"
        @network.link(l3_seg_node.name, l3_seg_tp.name, l3_node.name, l3_tp.name)
        @network.link(l3_node.name, l3_tp.name, l3_seg_node.name, l3_seg_tp.name) # bidirectional
      end

      # rubocop:disable Metrics/AbcSize

      # @param [Array<Netomox::PseudoDSL::PLinkEdge>] segment Edge list in same segment
      # @return [Array<Hash>] A list of 'prefix' attribute
      def collect_segment_prefixes(segment)
        prefixes = segment.map do |l2_edge|
          l2_node = @layer2p.node(l2_edge.node)
          l2_node.tps.map do |l2_tp|
            # target not only l2 term-point that connected to segment, but also unconnected one
            rec, = ip_rec_by_l2_node(l2_node, l2_tp.name)
            # debug_print "  prefix in Segment: #{l2_edge}] -> #{rec}"
            rec && IPAddress::IPv4.new("#{rec.ip}/#{rec.mask}")
          end
        end

        prefixes.flatten.compact.map { |ip| "#{ip.network}/#{ip.prefix}" }.uniq.map do |prefix|
          { prefix:, metric: 0 } # metric = 0 : default metric of connected route
        end
      end
      # rubocop:enable Metrics/AbcSize

      # pre calculation to decrease amount of calculation
      # @return [Hash<Integer, Array>] segment object_id to prefixes hash
      def setup_segment_to_prefixes_table
        @segments.each { |seg| @segment_prefixes[seg] = collect_segment_prefixes(seg) }
      end

      # @param [Array<Netomox::PseudoDSL::PLinkEdge>] segment Edge list in same segment
      # @return [String] Segment node suffix string
      def segment_node_suffix(segment)
        prefixes = @segment_prefixes[segment]
        if prefixes.length == 1
          "_#{prefixes[0][:prefix]}"
        elsif prefixes.length > 1
          # segment contains multiple ip prefixes
          "_#{prefixes[0][:prefix]}+"
        else
          # the segment does not have any prefix...L2 closed?
          ''
        end
      end

      # @param [Array<Netomox::PseudoDSL::PLinkEdge>] segment Edge list in same segment
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

      # @param [Array<Netomox::PseudoDSL::PLinkEdge>] segment Edge list in same segment
      # @return [String] Layer3 segment node name
      def segment_node_name(segment)
        seg_index = index_of_same_prefix_segment(segment)
        seg_suffix = segment_node_suffix(segment)
        name = seg_index.negative? ? "Seg#{seg_suffix}" : "Seg#{seg_suffix}##{seg_index}"
        @logger.warn "Segment node #{name} is L2 closed segment? " if seg_suffix.empty?
        name
      end

      # @param [Array<Netomox::PseudoDSL::PLinkEdge>] segment Edge list in same segment
      # @return [Netomox::PseudoDSL::PNode] Layer3 segment node
      def add_l3_seg_node(segment)
        # NOTICE: countermeasure of ip address block duplication
        #   If there are segments which are different but have same network prefix,
        #   Identify its segments with index number.
        l3_seg_node = @network.node(segment_node_name(segment))
        l3_seg_node.attribute = { prefixes: @segment_prefixes[segment], node_type: 'segment' }
        l3_seg_node
      end

      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize

      # Add all layer3 node, tp and link
      # @return [void]
      def add_l3_node_tp_link
        @segments.each_with_index do |segment, i|
          # segment: Array(Netomox::PseudoDSL::PLinkEdge)
          debug_print "# Segment#{i}: suffix = #{segment_node_suffix(segment)}"
          l3_seg_node = add_l3_seg_node(segment)
          segment.each do |l2_edge|
            l3_seg_node.supports.push([@layer2p.name, l2_edge.node])

            l2_node = @layer2p.node(l2_edge.node)
            debug_print "  - l2 edge=#{l2_edge}, l2 node=#{l2_node}"
            l2_node.tps.each do |l2_tp|
              debug_print "    - l2 tp: #{l2_node.name}[#{l2_tp.name}]"
              # target not only l2 term-point that connected to segment, but also unconnected one
              # for example: cisco Vlan(SVI) + L2 trunk pattern : L2 node has two interface, SVI and trunk.
              l3_node, l3_tp = add_l3_node_tp_by_l2_node_tp(l2_node, l2_tp)
              if l3_node.nil? || l3_tp.nil?
                @logger.info "Can not link: #{l3_seg_node.name} > #{l2_edge}, (it seems L2 link)"
                next
              end

              # Args: L3 (src_node, dst_node, dst_tp), L2 (dst_tp)
              l3_seg_tp = add_l3_seg_tp(l3_seg_node, l3_node, l3_tp, l2_edge)
              add_l3_link(l3_seg_node, l3_seg_tp, l3_node, l3_tp)
            end
          end
        end
      end
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

      # @param [String] l3_node_name L3 node name
      # @param [String] l3_tp_name L3 term-point name (in the L3 node)
      # @return [String, nil] VRF of the term-point (nil if error),
      #   "default" means GRT (Global Routing Table)
      def vrf_of_l3_intf(l3_node_name, l3_tp_name)
        prop = @intf_props.find_record_by_node_intf(l3_node_name, l3_tp_name)
        prop&.vrf
      end

      # @param [Netomox::PseudoDSL::PNode] l3_node L3 node name
      # @return [String] vrf name of L3 interfaces
      # @raise [StandardError] The node is NOT single vrf
      def detect_l3_node_vrf(l3_node)
        vrf_list = l3_node.tps.map { |l3_tp| vrf_of_l3_intf(l3_node.name, l3_tp.name) }
        vrf_list.uniq!
        return vrf_list[0] if vrf_list.length == 1

        raise StandardError, "Error: vrf of term-points in L3 node #{l3_node.name} is not unique."
      end

      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize

      # @return [void]
      def add_l3_loopback_tps
        debug_print('# Add L3 loopback tps')
        find_all_node_type_nodes.each do |l3_node|
          l3_node_vrf = detect_l3_node_vrf(l3_node)
          debug_print("- node:#{l3_node.name}, vrf=#{l3_node_vrf}")
          @ip_owners.find_all_loopbacks_by_node(l3_node.name).each do |lo|
            # ignore different vrf loopback
            next if vrf_of_l3_intf(l3_node.name, lo.interface) != l3_node_vrf

            debug_print("  - interface: #{lo.interface}")
            l3_tp = l3_node.term_point(lo.interface)
            l3_tp.attribute = { ip_addrs: ["#{lo.ip}/#{lo.mask}"], flags: %w[loopback] }
          end
        end
      end
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

      # @return [Array<Netomox::PseudoDSL::PNode>] Found nodes
      def find_all_node_type_nodes
        @network.nodes.filter { |n| %w[node endpoint].include?(n.attribute[:node_type]) }
      end

      # @param [Netomox::PseudoDSL::PNode] l3_node Layer3 node
      # @return [Array<Netomox::PseudoDSL::PTermPoint>] Found term-points
      def find_all_l3_tps_has_ipaddr(l3_node)
        l3_node.tps.filter { |tp| tp.attribute[:ip_addrs]&.length&.positive? }
      end

      # @param [Netomox::PseudoDSL::PNode] l3_node Layer3 node
      # @return [Array<Hash>] A list of layer3 node prefix (connected routes)
      def node_prefixes_at_l3_node(l3_node)
        find_all_l3_tps_has_ipaddr(l3_node).map do |tp|
          ip = IPAddress::IPv4.new(tp.attribute[:ip_addrs][0])
          { prefix: "#{ip.network}/#{ip.prefix}", metric: 0, flags: %w[connected] }
        end
      end

      # @param [Netomox::PseudoDSL::PNode] l3_node Update target node
      # @return [void]
      def update_node_prefix_attr(l3_node)
        prefixes = node_prefixes_at_l3_node(l3_node)
        debug_print "- node: #{l3_node.name}, prefixes: #{prefixes}"
        l3_node.attribute[:prefixes] = prefixes
      end

      # @param [Netomox::PseudoDSL::PNode] l3_node Update target node
      # @return [Array<Hash>]
      def node_static_routes_at_l3_node(l3_node)
        @routes.find_all_records_by_node_proto(l3_node.name, 'static').map do |route|
          {
            prefix: route.network,
            next_hop: route.next_hop_ip,
            interface: route.next_hop_interface,
            metric: route.metric,
            preference: route.admin_distance
          }
        end
      end

      # @param [Netomox::PseudoDSL::PNode] l3_node Update target node
      # @return [void]
      def update_node_static_route_attr(l3_node)
        static_routes = node_static_routes_at_l3_node(l3_node)
        debug_print "- node: #{l3_node.name}, static-routes: #{static_routes.length}"
        l3_node.attribute[:static_routes] = static_routes
      end

      # Set layer3 node attribute (prefixes) according to its term-point
      # @return [void]
      def update_node_attribute
        debug_print '# update node attribute'
        find_all_node_type_nodes.each do |l3_node|
          update_node_prefix_attr(l3_node)
          update_node_static_route_attr(l3_node)
        end
      end

      # @param [Netomox::PseudoDSL::PNode] l2_node Node name (L2)
      # @param [Netomox::PseudoDSL::PTermPoint] l2_tp Term-point name (of the L2 node)
      # @return [Boolean] true if the term-point is linked
      def linked_l2_tp?(l2_node, l2_tp)
        l2_link = @layer2p.find_link_by_src_name(l2_node.name, l2_tp.name)
        !l2_link.nil?
      end

      # add unlinked interface which owns ip address (interface to external network/AS)
      # @return [void]
      def add_unlinked_ip_owner_tp
        debug_print '# add_unlinked_ip_owner_tp'
        @layer2p.nodes.each do |l2_node|
          debug_print "  - target node: #{l2_node.name}"
          l2_node.tps.each do |l2_tp|
            # nothing to do if the term-point is linked (L2)
            next if linked_l2_tp?(l2_node, l2_tp)

            debug_print "    find unlinked tp: #{l2_tp.name}"
            add_l3_node_tp_by_l2_node_tp(l2_node, l2_tp)
          end
        end
      end
    end
  end
end
# rubocop:enable Metrics/ClassLength
