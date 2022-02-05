# frozen_string_literal: true

require 'test-unit'
require 'json'

# Test traceroute result (json)
class TestTracerouteResult < Test::Unit::TestCase
  JSON.parse(File.read('.traceroute_result.json')).each do |pattern|
    sub_test_case "PATTERN: #{pattern['pattern']}" do
      pattern['cases'].each do |test_case|
        sub_test_case "CASE: #{test_case['case'][0]} -> #{test_case['case'][1]}" do
          test_case['traceroute'].each do |trace|
            test "#{trace[0]}/#{trace[1]} <#{trace[2]}>" do
              assert_equal('ACCEPTED', trace[3])
            end
          end
        end
      end
    end
  end
end
