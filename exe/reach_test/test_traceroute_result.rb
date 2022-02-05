# frozen_string_literal: true

require 'test-unit'
require 'json'

# Test traceroute result (json)
class TestTracerouteResult < Test::Unit::TestCase
  JSON.parse(File.read('.traceroute_result.json')).each do |pattern|
    sub_test_case "pattern: #{pattern['pattern']}" do
      pattern['cases'].each do |test_case|
        test_descr = "#{test_case[2]}/#{test_case[3]} (#{test_case[4]})"
        test "#{test_case[0]}->#{test_case[1]} in #{test_descr}" do
          assert_equal('ACCEPTED', test_case[5])
        end
      end
    end
  end
end
