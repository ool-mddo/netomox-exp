# frozen_string_literal: true

require_relative './l1_intf_descr_ops_base'

module TopologyOperator
  # Layer1 interface description checker
  class L1InterfaceDescriptionChecker < L1InterfaceDescriptionOpsBase
    # @param [String] level Output type level
    # @return [Array<Hash>] Level-filtered description check results
    def check(level)
      @level = level
      descr_check_data.filter { |datum| level_match(datum[:type]) }
    end

    private

    # @param [Netomox::Topology::TermPoint] term_point (Source) term-point of description check target
    # @param [Netomox::Topology::Link] link Target link
    # @return [Hash] check result for a term-point
    def descr_check_datum(term_point, link)
      if empty_descr?(term_point)
        descr_check_result(:warning, term_point, link, 'Empty description')
      elsif correct_descr?(term_point, link.destination)
        descr_check_result(:info, term_point, link, 'Correct')
      else
        descr_check_result(:warning, term_point, link, 'Incorrect format')
      end
    end

    # @return [Array<Hash>] description check results for all term-points
    def descr_check_data
      @l1_nw.links.map do |link|
        # check only source interface because links are bidirectional
        src_tp = @l1_nw.find_node_by_name(link.source.node_ref)&.find_tp_by_name(link.source.tp_ref)
        return descr_check_result(:error, src_tp, link, 'term_point not found') unless src_tp

        descr_check_datum(src_tp, link)
      end
    end

    # @param [Symbol] type Type of a check result
    # @param [Netomox::Topology::TermPoint] term_point Target term-point
    # @param [Netomox::Topology::Link] link Target link
    # @param [String] message Message
    # @return [Hash]
    def descr_check_result(type, term_point, link, message)
      {
        type: type,
        term_point: term_point.path,
        link: link.path,
        message: message
      }
    end

    # @param [Symbol] data_type Type of a check result
    #   NOTE: give `@level` from CLI frontend when `#check`
    # @return [Boolean] true if the data type is higher priority
    def level_match(data_type)
      case @level
      when 'error'
        data_type == :error
      when 'warning'
        %i[warning error].include?(data_type)
      else # type 'info' : accept any
        true
      end
    end

    # @param [Netomox::Topology::TermPoint] term_point Target term-point
    # @return [Boolean] true if the description of the term_point is empty
    def empty_descr?(term_point)
      # respond_to?(attr) attr.descr.empty? result
      #        F                 -            T
      #        T                 T            T
      #        T                 F            F
      !term_point.attribute.respond_to?(:description) || term_point.attribute.description.empty?
    end

    # @param [Netomox::Topology::TermPoint] term_point Target term-point
    # @param [Netomox::Topology::TpRef] facing_edge Facing (destination) term-point of the term-point
    # @return [Boolean] true if the term-point description is correct format
    def correct_descr?(term_point, facing_edge)
      # description format: specify its destination interface information as: "to_HOST_INTERFACE"
      return false unless term_point.attribute.description =~ /to_(\S+)_(\S+)/

      descr_host = Regexp.last_match(1)
      descr_tp = Regexp.last_match(2)
      # ignore upper/loser case difference,
      # but abbreviated interface type is NOT allowed (e.g. GigabitEthernet0/0 <=> Gi0/0)
      descr_host&.downcase == facing_edge.node_ref.downcase && descr_tp&.downcase == facing_edge.tp_ref.downcase
    end
  end
end
