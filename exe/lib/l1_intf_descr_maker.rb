# frozen_string_literal: true

require 'csv'
require_relative './l1_intf_descr_ops_base'

# Layer1 interface description maker
class L1InterfaceDescriptionMaker < L1InterfaceDescriptionOpsBase
  # @param [String] output_file File path to output layer1 description data (csv)
  #   if it is empty, output $stdout data.
  # @return [void]
  def make(output_file)
    csv_body = proc do |csv_out|
      header = %w[Source_Node Source_Interface Destination_Node Destination_Interface Source_Interface_Description]
      csv_out << ([''] + header) # number column (empty column header) + header
      layer1_link_table.each { |rec| csv_out << ordering_layer1_link_table_rec(rec) }
    end

    if output_file.empty?
      CSV { |csv_out| csv_body.call(csv_out) } # to $stdout
    else
      CSV.open(output_file, 'w') { |csv_out| csv_body.call(csv_out) }
    end
  end

  private

  # Reorder layer1 interface description data (`#layer1_link_table`) to CSV row data
  # @param [Hash] rec Layer1 interface description datum
  # @return [Array<String>] CSV raw data
  def ordering_layer1_link_table_rec(rec)
    [
      rec[:number],
      normal_hostname(rec[:src_node]), rec[:src_tp],
      normal_hostname(rec[:dst_node]), rec[:dst_tp],
      "to_#{normal_hostname(rec[:dst_node])}_#{rec[:dst_tp]}"
    ]
  end

  # rubocop:disable Metrics/MethodLength

  # @return [Array<Hash>] layer1 interface description data
  def layer1_link_table
    @l1_nw.links.map.with_index do |link, i|
      src = link.source
      dst = link.destination
      {
        number: i + 1,
        src_node: src.node_ref,
        src_tp: src.tp_ref,
        dst_node: dst.node_ref,
        dst_tp: dst.tp_ref
      }
    end
  end
  # rubocop:enable Metrics/MethodLength

  # Normalize hostname because batfish makes all hostnames lowercase.
  #   NOTE: for MDDO project hostname rule.
  # @param [String] hostname Host name to normalize
  # @return [String] Normalized host name
  def normal_hostname(hostname)
    hostname.gsub!(/region([ab])-(pe|ce)(\d+)/) do
      "Region#{Regexp.last_match(1).upcase}-#{Regexp.last_match(2).upcase}#{Regexp.last_match(3)}"
    end
    hostname.gsub!(/region([ab])-(acc|svr)(\d+)/) do
      "Region#{Regexp.last_match(1).upcase}-#{Regexp.last_match(2).capitalize}#{Regexp.last_match(3)}"
    end
    hostname
  end
end
