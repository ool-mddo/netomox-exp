# frozen_string_literal: true

require 'json'
require 'httpclient'
require_relative 'reach_pattern_handler'

module TopologyOperator
  # Batfish traceroute data operations
  class BFTracerouteResults
    # @param [Array<Hash>] bft_results Output of Batfish traceroute query
    def initialize(bft_results)
      @bft_results = bft_results # array
    end

    # @return [Array<Hash>]
    def to_data
      # - network: str
      #   snapshot: str
      #   result: [ bft_result ]
      @bft_results.map do |bft_result|
        {
          network: bft_result['network'],
          snapshot: bft_result['snapshot'],
          results: simplify_bft_results(bft_result['result'])
        }
      end
    end

    private

    # @param [Array<Hash>] bft_results
    # @return [Array<Hash]
    def simplify_bft_results(bft_results)
      # - Flow: {}
      #   Traces: [ trace ]
      bft_results.map do |bft_result|
        {
          flow: simplify_flow(bft_result['Flow']),
          traces: simplify_traces(bft_result['Traces'])
        }
      end
    end

    # @param [Hash] flow Batfish flow
    # @return [Hash] Simplified flow
    def simplify_flow(flow)
      keys = %w[dstIp dstPort ingressInterface ingressNode ipProtocol srcIp srcPort]
      flow.slice(*keys)
    end

    # @param [Array<Hash>] traces
    # @return [Array<Hash>]
    def simplify_traces(traces)
      # - disposition: str
      #   hops: [ hop ]
      traces.map do |trace|
        {
          disposition: trace['disposition'],
          hops: simplify_hops(trace['hops'])
        }
      end
    end

    # @param [Array<Hash>] hops
    # @return [Array<String>] Simplified hops (list of node[interface])
    def simplify_hops(hops)
      # - node: str
      #   steps:
      #     - action
      #     - detail
      hops.map do |hop|
        node = hop['node']
        received_hop = hop['steps'].find { |step| step['action'] == 'RECEIVED' }
        "#{node}[#{received_hop['detail']['inputInterface']}]"
      end
    end
  end

  # Reachability tester
  class ReachTester
    # @param [String] pattern_file Test pattern file name (json)
    def initialize(pattern_file)
      reach_ops = ReachPatternHandler.new(pattern_file)
      @patterns = reach_ops.expand_patterns.reject { |pt| pt[:cases].empty? }
      @client = HTTPClient.new
    end

    # @param [String] bf_network Network name to analyze (in batfish)
    # @return [Array<Hash>]
    def exec_all_tests(bf_network)
      @patterns.map do |pattern|
        {
          pattern: pattern[:pattern],
          cases: pattern[:cases].map { |c| exec_test(c, bf_network) }
        }
      end
    end

    private

    # @param [Hash] test_case Expanded test case (@see ReachPatternHandler#expand_cases)
    # @return [Hash] Query parameter for batfish traceroute
    def traceroute_query(test_case, bf_network)
      {
        'interface' => test_case[:src][:intf],
        'destination' => test_case[:dst][:intf_ip],
        'network' => bf_network
      }
    end

    # @param [Hash] test_case Expanded test case
    # @param [String] bf_network Network name to analyze (in batfish)
    # @return [Hash]
    def exec_test(test_case, bf_network)
      url = "http://localhost:5000/api/nodes/#{test_case[:src][:node]}/traceroute"
      res = @client.get(url, query: traceroute_query(test_case, bf_network))
      {
        case: test_case,
        traceroute: BFTracerouteResults.new(JSON.parse(res.body)).to_data
      }
    end
  end
end
