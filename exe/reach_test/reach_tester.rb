# frozen_string_literal: true

require 'json'
require 'httpclient'
require_relative 'reach_pattern_handler'
require_relative 'bf_trace_results'
require_relative 'bf_wrapper_query_base'

module TopologyOperator
  # Reachability tester
  class ReachTester < BFWrapperQueryBase
    # @param [String] pattern_file Test pattern file name (json)
    def initialize(pattern_file)
      super()
      reach_ops = ReachPatternHandler.new(pattern_file)
      @patterns = reach_ops.expand_patterns.reject { |pt| pt[:cases].empty? }
    end

    # @param [String] bf_network Network name to analyze (in batfish)
    # @return [Array<Hash>]
    def exec_all_tests(bf_network)
      snapshots = fetch_snapshots(bf_network)
      @patterns.map do |pattern|
        {
          pattern: pattern[:pattern],
          cases: pattern[:cases].map { |c| exec_test(c, bf_network, snapshots) }
        }
      end
    end

    private

    # @param [Hash] test_case Expanded test case
    # @param [String] bf_network Network name to analyze (in batfish)
    # @param [Array<String>] snapshots Snapshot names in bf_network
    # @return [Hash]
    def exec_test(test_case, bf_network, snapshots)
      traceroute_results = snapshots.map do |snapshot|
        {
          network: bf_network,
          snapshot: snapshots,
          # TODO: check: traceroute returns single object?
          result: [fetch_traceroute(bf_network, snapshot,
                                    test_case[:src][:node], test_case[:src][:intf], test_case[:dst][:intf_ip])]
        }
      end
      { case: test_case, traceroute: BFTracerouteResults.new(traceroute_results).to_data }
    end
  end
end
