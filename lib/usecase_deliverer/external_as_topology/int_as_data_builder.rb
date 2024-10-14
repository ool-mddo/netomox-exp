# frozen_string_literal: true

require 'netomox'
require 'ipaddr'

module NetomoxExp
  module UsecaseDeliverer
    # Internal-AS peer data builder
    class IntAsDataBuilder
      # @!attribute [r] as_state
      #   @return [Hash]
      # @!attribute [r] int_as_topology
      #   @return [Netomox::Topology::Networks]
      attr_reader :as_state, :int_as_topology

      # @param [String] usecase Usecase name
      # @param [Symbol] as_type (enum: [source_as, :dest_as])
      # @param [Hash] usecase_params Params data
      # @param [Netomox::Topology::Networks] int_as_topology Internal AS topology (original_asis)
      def initialize(usecase, as_type, usecase_params, int_as_topology)
        # usecase name
        @usecase = usecase
        # self (internal) AS topology
        @int_as_topology = int_as_topology

        # single (target) as params
        @params = usecase_params[as_type.to_s]
        # peer info
        @peer_list = find_all_peers(@params['asn'])
        # target AS info
        @as_state = make_as_state(as_type)
      end

      protected

      # @return [Boolean] true if AS params (@params) is region-separated data
      def region_as_params?
        return false if @params.key?('allowed_peers') && !@params.key?('regions')
        return true if @params.key?('regions') && !@params.key?('allowed_peers')

        false # default
      end

      private

      # @param [Symbol] as_type (enum: [source_as, :dest_as])
      # @return [Hash] as_state
      def make_as_state(as_type)
        {
          type: as_type,
          int_asn: @peer_list.map { |item| item[:bgp_proc][:local_as] }.uniq[0],
          ext_asn: @peer_list.map { |item| item[:bgp_proc][:remote_as] }.uniq[0]
        }
      end

      # @param [String] layer3_node_name
      # @param [String] layer3_tp_name
      # @return [String] ip address of the interface
      def find_layer3_tp_ip_addr(layer3_node_name, layer3_tp_name)
        layer3_nw = @int_as_topology.find_network('layer3')
        layer3_node = layer3_nw.find_node_by_name(layer3_node_name)
        layer3_tp = layer3_node.find_tp_by_name(layer3_tp_name)
        layer3_tp.attribute.ip_addrs[0]
      end

      # @param [String] remote_ip Remote IP addr (in tp_attr)
      # @return [Boolean] true if allowed_peer
      def allowed_peer?(remote_ip)
        # for pni usecases or dest_peer in multi_region usecase
        return @params['allowed_peers'].include?(remote_ip) unless region_as_params?

        # for multi_region_te usecase
        @params['regions'].any? do |region|
          region['allowed_peers'].map { |peer| peer['peer'] }.include?(remote_ip)
        end
      end

      # @param [Netomox::Topology::TermPoint] bgp_proc_tp Internal-AS eBGP term-point
      # @param [Integer] remote_asn Remote ASN
      # @return [Boolean] true if target eBGP edge
      def target_ebgp_peer?(bgp_proc_tp, remote_asn)
        tp_attr = bgp_proc_tp.attribute
        tp_attr.remote_as == remote_asn && allowed_peer?(tp_attr.remote_ip)
      end

      # find peer info for multi_region usecase
      # @param [String] remote_ip
      # return [Hash] empty hash if not found
      def find_peer_by_remote_ip(remote_ip)
        @params['regions'].each do |region|
          allowed_peer = region['allowed_peers'].find { |peer| peer['peer'] == remote_ip }
          next if allowed_peer.nil?

          return {
            type: :region,
            region: region['region'],
            peer_type: allowed_peer['type']
          }
        end
        {} # not found
      end

      # @param [Netomox::Topology::Node] bgp_proc_node BGP-proc node (int-AS)
      # @param [Netomox::Topology::TermPoint] bgp_proc_tp BGP-proc term-point
      # @return [Hash]
      def make_peer_item_bgp_proc(bgp_proc_node, bgp_proc_tp)
        tp_attr = bgp_proc_tp.attribute
        {
          type: :simple,
          node_name: bgp_proc_node.name,
          tp_name: bgp_proc_tp.name,
          local_as: tp_attr.confederation.negative? ? tp_attr.local_as : tp_attr.confederation,
          local_ip: tp_attr.local_ip,
          remote_as: tp_attr.remote_as,
          remote_ip: tp_attr.remote_ip
        }
      end

      # @param [Netomox::Topology::SupportingTerminationPoint] layer3_ref Support of a bgp-proc node (int-AS)
      # @return [Hash]
      def make_peer_item_layer3(layer3_ref)
        {
          node_name: layer3_ref.ref_node,
          tp_name: layer3_ref.ref_tp,
          ip_addr: find_layer3_tp_ip_addr(layer3_ref.ref_node, layer3_ref.ref_tp)
        }
      end

      # @param [Netomox::Topology::Node] bgp_proc_node Internal-AS eBGP node
      # @param [Netomox::Topology::TermPoint] bgp_proc_tp Internal-AS eBGP term-point
      # @return [Hash] peer_item
      def make_peer_item(bgp_proc_node, bgp_proc_tp)
        layer3_ref = bgp_proc_tp.supports.find { |s| s.ref_network == 'layer3' }
        peer_data = region_as_params? ? find_peer_by_remote_ip(bgp_proc_tp.attribute.remote_ip) : {}
        {
          bgp_proc: make_peer_item_bgp_proc(bgp_proc_node, bgp_proc_tp).merge(peer_data),
          layer3: make_peer_item_layer3(layer3_ref).merge(peer_data)
        }
      end

      # @param [Integer] remote_asn Remote ASN
      # @return [Array<Hash>] peer list
      def find_all_peers(remote_asn)
        peer_list = []
        bgp_proc_nw = @int_as_topology.find_network('bgp_proc')
        bgp_proc_nw.nodes.each do |bgp_proc_node|
          bgp_proc_node.termination_points.each do |bgp_proc_tp|
            next unless target_ebgp_peer?(bgp_proc_tp, remote_asn)

            peer_list.push(make_peer_item(bgp_proc_node, bgp_proc_tp))
          end
        end
        # [                                   ... peer_list
        #   {                                 ... peer_item
        #     :bgp_proc => {
        #       :node_name => "192.168.255.5",
        #       # :node => Netomox::PseudoDSL::PNode  ... bgp_proc node
        #       :tp_name => "peer_172.16.0.5",
        #       :local_as => 65500,
        #       :local_ip => "172.16.0.6",
        #       :remote_as => 65518,          ... NOTICE: confederation
        #       :remote_ip => "172.16.0.5"
        #     },
        #     :layer3 => {
        #       :node_name => "edge-tk01",
        #       # :node => Netomox::PseudoDSL::PNode  ... layer3 node
        #       :tp_name => "ge-0/0/3.0",
        #       :ip_addr => "172.16.0.6/30"
        #     }
        #   },
        #   ...
        # ]
        peer_list
      end
    end
  end
end
