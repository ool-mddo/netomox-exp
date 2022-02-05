# frozen_string_literal: true

module TopologyOperator
  # convert reachability test results
  class ReachResultConverter
    def initialize(traceroute_results)
      @traceroute_results = traceroute_results
    end

    # @return [Array<Hash>]
    def summary
      @traceroute_results.map do |traceroute_result|
        {
          pattern: pattern_str(traceroute_result[:pattern]),
          cases: summary_cases(traceroute_result[:cases])
        }
      end
    end

    # @return [Array<Array<String>>]
    def full_table
      rows = @traceroute_results.map do |traceroute_result|
        summary_cases(traceroute_result[:cases]).map do |sr|
          [pattern_str(traceroute_result[:pattern]), *sr]
        end
      end
      header = [%w[Pattern Source Destination Network Snapshot Description Deposition Hops]]
      header.concat(rows.flatten(1))
    end

    private

    # @param [Array<String>] pattern Test pattern (src group, dst group)
    # @return [String]
    def pattern_str(pattern)
      "#{pattern[0]}->#{pattern[1]}"
    end

    # @param [Array] test_cases Test cases
    # @return [Array<Array<String>>]
    def summary_cases(test_cases)
      test_cases.map { |test_case| cases_to_array(test_case) }
                .flatten(2)
    end

    # @param [Hash] target Source or Destination of test case
    # @return [String]
    def case_str(target)
      "#{target[:node]}[#{target[:intf]}](#{target[:intf_ip]})"
    end

    # @param [Hash] test_case Test case data
    # @return [Array<Array<String>>]
    def cases_to_array(test_case)
      src = case_str(test_case[:case][:src])
      dst = case_str(test_case[:case][:dst])
      test_case[:traceroute].map do |trace|
        summary_trace(trace).map { |st| [src, dst, *st] }
      end
    end

    # @param [Hash] trace Traceroute data in test case data
    # @return [Array<Array<<String>>]
    def summary_trace(trace)
      summary_results(trace[:results]).map do |sr|
        descr = trace[:snapshot_info]['description']
        [trace[:network], trace[:snapshot], descr, *sr]
      end
    end

    # @param [Array<Hash>] results Traceroute results of traceroute data
    # @return [Array<String>]
    def summary_results(results)
      # warn "# results: #{results}"
      results.each.map do |result|
        result[:traces].map { |trace| [trace[:disposition], trace[:hops].join('->')] }
                       .flatten
      end
    end
  end
end
