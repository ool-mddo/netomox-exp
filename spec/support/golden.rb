# frozen_string_literal: true

# golden master helper (use sparingly: only for small, readable data)
#   regenerate: UPDATE_GOLDEN=1 bundle exec rspec  (and REVIEW the diff!)
module GoldenHelper
  GOLDEN_DIR = File.join(SPEC_ROOT, 'fixtures', 'golden')

  module_function

  # @param [Object] data json-like object
  # @return [Object] normalized data (hash keys sorted recursively; array order is kept)
  def normalize(data)
    case data
    when Hash then data.sort_by { |k, _| k.to_s }.to_h { |k, v| [k, normalize(v)] }
    when Array then data.map { |v| normalize(v) }
    else data
    end
  end

  # @param [String] name golden file name
  # @param [Object] actual
  # @return [Object] expected data
  def expected(name, actual)
    path = File.join(GOLDEN_DIR, name)
    File.write(path, "#{JSON.pretty_generate(normalize(actual))}\n") if ENV['UPDATE_GOLDEN']
    JSON.parse(File.read(path))
  end
end
