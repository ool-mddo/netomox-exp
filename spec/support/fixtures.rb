# frozen_string_literal: true

# helpers to load fixtures
module FixtureHelper
  FIXTURE_DIR = File.join(SPEC_ROOT, 'fixtures')

  module_function

  # @return [String] fixture file path
  def path(*names)
    File.join(FIXTURE_DIR, *names)
  end

  # @return [Hash] FW HA cluster topology (copied from topologies/mddo-fw/original_asis)
  def fw_topology
    JSON.parse(File.read(path('topologies', 'mddo-fw', 'original_asis.topology.json')))
  end

  # @return [Hash] usecase params (refocus_topology/mddo-fw)
  def refocus_params
    YAML.load_file(path('usecases', 'refocus_topology', 'mddo-fw', 'params.yaml'))
  end

  # deep copy of json-like data
  def deep_dup(data)
    JSON.parse(JSON.generate(data))
  end
end
