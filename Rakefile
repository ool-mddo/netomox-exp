# frozen_string_literal: true

require 'rake'
require 'rake/clean'
require 'json'
require 'httpclient'
require 'parallel'

CONFIGS_DIR = ENV.fetch('MDDO_CONFIGS_DIR', 'configs')
MODELS_DIR = ENV.fetch('MDDO_MODELS_DIR', 'models')
NETOVIZ_DIR = ENV.fetch('MDDO_NETOVIZ_MODEL_DIR', 'netoviz_model')
USE_PARALLEL = ENV.fetch('MDDO_USE_PARALLEL', nil)
MODEL_DEFS_DIR = 'model_defs'
BATFISH_WRAPPER_HOST = ENV.fetch('BATFISH_WRAPPER_HOST', 'localhost:5000')
BFW_CLIENT = HTTPClient.new
BFW_CLIENT.receive_timeout = 60 * 60 * 4 # 60sec * 60min * 4h

# netoviz index file
NETOVIZ_INDEX = File.join(NETOVIZ_DIR, '_index.json')

# Load model info data
MODEL_INFO = JSON.parse(File.read('./model_info.json'), { symbolize_names: true })
MODEL_INFO.each do |mi|
  mi[:type] = mi[:type].intern # change value of :type key to symbol
end

task default: %i[model_dirs simulation_pattern snapshot_to_model netoviz_index netoviz_model netoviz_layout
                 logical_ss_diff]

desc 'Make directories for models and netoviz'
task :model_dirs do
  puts '# Make directories'
  sh "mkdir -p #{NETOVIZ_DIR}"
  sh "mkdir -p #{MODELS_DIR}"
  puts '# Clean models dir'
  sh "rm -rf #{MODELS_DIR}/*"
end

def post_bfw(api_path, data)
  header = { 'Content-Type' => 'application/json' }
  body = JSON.generate(data)
  url = "http://#{BATFISH_WRAPPER_HOST}/#{api_path}"
  puts "- POST: #{url}, data=#{data}"
  BFW_CLIENT.post url, body: body, header: header
end

def find_model_info_by_nw_ss(network, snapshot)
  MODEL_INFO.find { |mi| mi[:network] == network && mi[:snapshot] == snapshot }
end

def find_all_model_info_by_nw(network)
  MODEL_INFO.find_all { |mi| mi[:network] == network }
end

def find_all_model_info_by_type(*model_info_type)
  model_info = ENV['NETWORK'] ? find_all_model_info_by_nw(ENV.fetch('NETWORK')) : MODEL_INFO
  model_info.find_all { |mi| model_info_type.include?(mi[:type]) }
end

desc 'Generate snapshot patterns of simulation target networks'
task :simulation_pattern do
  if ENV['PHY_SS_ONLY']
    puts '# Pass snapshot pattern generation'
    find_all_model_info_by_type(:simulation_target).each do |model_info|
      snapshot_dir = File.join(CONFIGS_DIR, model_info[:network], model_info[:snapshot])
      pattern_file = File.join(snapshot_dir, 'snapshot_patterns.json')
      sh "rm -f #{pattern_file}"
    end
    next
  end

  puts '# Generate snapshot patterns'
  opt = {}
  if ENV['OFF_NODE']
    opt['node'] = ENV.fetch('OFF_NODE', nil)
    opt['interface_regexp'] = ENV.fetch('OFF_INTF_RE', nil) if ENV['OFF_INTF_RE']
  end
  find_all_model_info_by_type(:simulation_target).each do |model_info|
    post_bfw("api/networks/#{model_info[:network]}/snapshots/#{model_info[:snapshot]}/patterns", opt)
  end
end

desc 'Generate model data (csv) from snapshots'
task :snapshot_to_model do
  puts '# Generate model data'
  # NOTICE: CANNOT parallel: because batfish-wrapper does not correspond multiple access
  find_all_model_info_by_type(:fixed, :simulation_target)
    .uniq { |mi| mi[:network] } # batfish-wrapper queries for all snapshots in the network dir.
    .each { |model_info| post_bfw("api/networks/#{model_info[:network]}/queries", {}) }
end

# @return [Array(Array(String, String))] Pairs of network and snapshot of models csv
#   e.g. [[network, snapshot], [network, snapshot/snapshot], ...]
def models_list
  Dir.glob("#{MODELS_DIR}/**/*/*.csv")
     .map { |csv| File.dirname(csv) }
     .sort
     .uniq
     .map { |dir| dir.gsub(%r{^#{MODELS_DIR}/?}, '') }
     .map { |dir| dir.split('/') }
     .reject { |names| names.length < 2 } # reject except `network/snapshot(/snapshot)` format dir
     .map { |names| [names[0], names[1..].join('/')] } # unsafe snapshot name (snapshot path)
end

def index_label(network, snapshot)
  models_snapshot_dir = File.join(MODELS_DIR, network, snapshot)
  snapshot_pattern = File.join(models_snapshot_dir, 'snapshot_pattern.json')
  if File.exist?(snapshot_pattern)
    data = JSON.parse(File.read(snapshot_pattern), { symbolize_names: true })
    model_info = find_model_info_by_nw_ss(network, data[:orig_snapshot_name])
    "#{model_info[:label]} #{data[:description]}"
  else
    model_info = find_model_info_by_nw_ss(network, snapshot)
    model_info[:label]
  end
end

desc 'Generate netoviz index file'
task :netoviz_index do
  puts '# Generate netoviz index file'
  index_data = models_list.map do |network, snapshot|
    {
      'network' => network,
      'snapshot' => snapshot,
      'file' => 'topology.json',
      'label' => index_label(network, snapshot)
    }
  end
  File.write(NETOVIZ_INDEX, JSON.pretty_generate(index_data))
end

# @param [Array<Object>] target_data Target data to operate
# @yield [datum] instructions for each datum
# @yieldparam [Object] datum A datum in target_data
def parallel_executables(target_data, &block)
  if USE_PARALLEL
    Parallel.each(target_data, &block)
  else
    target_data.each(&block)
  end
end

desc 'Generate topology files (for netoviz)'
task :netoviz_model do
  puts '# Generate topology files'
  # clean logical snapshot data
  sh "find #{NETOVIZ_DIR} -type d -name '*_linkdown_*' | xargs rm -rf"
  sh "find #{NETOVIZ_DIR} -type d -name '*_drawoff' | xargs rm -rf"

  parallel_executables(models_list) do |network, snapshot|
    models_snapshot_dir = File.join(MODELS_DIR, network, snapshot)
    netoviz_snapshot_dir = File.join(NETOVIZ_DIR, network, snapshot)
    sh "mkdir -p #{netoviz_snapshot_dir}"
    topo_file = File.join(netoviz_snapshot_dir, 'topology.json')
    sh "bundle exec ruby #{MODEL_DEFS_DIR}/mddo_trial.rb -i #{models_snapshot_dir} > #{topo_file}"
  end
end

desc 'Copy netoviz layout files'
task :netoviz_layout do
  puts '# Copy netoviz layout files'
  parallel_executables(models_list) do |network, snapshot|
    netoviz_snapshot_dir = File.join(NETOVIZ_DIR, network, snapshot)
    layout_file = File.join(MODEL_DEFS_DIR, 'layout', network, snapshot, 'layout.json')
    sh "cp #{layout_file} #{netoviz_snapshot_dir}" if File.exist?(layout_file)
  end
end

def make_topology_diff(src_topology, dst_topology)
  topology_diff = File.join(File.dirname(dst_topology), "#{File.basename(dst_topology)}.diff")
  sh "bundle exec netomox diff -o #{topology_diff} #{src_topology} #{dst_topology}"
end

desc 'Generate diff data of linkdown snapshots and overwrite'
task :logical_ss_diff do
  puts '# Generate diff data'
  # clean
  sh "find #{NETOVIZ_DIR} -name '*.diff' | xargs rm -f"

  find_all_model_info_by_type(:simulation_target).each do |model_info|
    network = model_info[:network]
    orig_snapshot = model_info[:snapshot]
    orig_topology = File.join(NETOVIZ_DIR, network, orig_snapshot, 'topology.json')
    src_topology = orig_topology

    # drawoff if exists
    drawoff_topology = File.join(NETOVIZ_DIR, network, "#{orig_snapshot}_drawoff", 'topology.json')
    if File.exist?(drawoff_topology)
      make_topology_diff(orig_topology, drawoff_topology)
      src_topology = drawoff_topology
    end

    # linkdown
    linkdown_topologies_glob = File.join(NETOVIZ_DIR, network, "#{orig_snapshot}_linkdown_*", 'topology.json')
    linkdown_topologies = Dir.glob(linkdown_topologies_glob)
    parallel_executables(linkdown_topologies) do |linkdown_topology|
      make_topology_diff(src_topology, linkdown_topology)
    end

    # overwrite diff files
    next if ENV.fetch('DISABLE_DIFF_OVERWRITE', nil)

    topology_diffs_glob = File.join(NETOVIZ_DIR, network, "#{orig_snapshot}_*", '*.diff')
    topology_diffs = Dir.glob(topology_diffs_glob)
    parallel_executables(topology_diffs) do |topology_diff|
      sh "mv #{topology_diff} #{topology_diff.gsub(File.extname(topology_diff), '')}"
    end
  end
end

desc 'Generate diff data between emulated-asis/tobe snapshot'
task :emulated_ss_diff do
  puts '# Generate diff data between emulated-asis/tobe snapshot'
  # clean logical snapshot data
  sh "find #{NETOVIZ_DIR} -type d -name 'emulated_diff' | xargs rm -rf "

  index_diffs = find_all_model_info_by_type(:simulation_target).uniq { |mi| mi[:network] }.map do |model_info|
    src_topo_file = File.join(NETOVIZ_DIR, model_info[:network], 'emulated_asis', 'topology.json')
    dst_topo_file = File.join(NETOVIZ_DIR, model_info[:network], 'emulated_tobe', 'topology.json')
    next unless File.exist?(src_topo_file) && File.exist?(dst_topo_file)

    diff_dir = File.join(NETOVIZ_DIR, model_info[:network], 'emulated_diff')
    diff_file = File.join(diff_dir, 'topology.json')
    sh "mkdir -p #{diff_dir}"
    sh "bundle exec netomox diff -o #{diff_file} #{src_topo_file} #{dst_topo_file}"

    {
      'network' => model_info[:network],
      'snapshot' => 'emulated_diff',
      'file' => 'topology.json',
      'label' => "Topoology diff of #{model_info[:network]} emulated_asis/tobe"
    }
  end
  netoviz_index_data = JSON.parse(File.read(NETOVIZ_INDEX))
  File.write(NETOVIZ_INDEX, JSON.pretty_generate(netoviz_index_data.concat(index_diffs)))
end

#######################
# tasks for development

begin
  require 'rubocop/rake_task'
  RuboCop::RakeTask.new
rescue LoadError
  task :rubocop do
    warn 'RuboCop is disabled'
  end
end

begin
  require 'yard'
  require 'yard/rake/yardoc_task'
  YARD::Rake::YardocTask.new do |task|
    task.files = FileList[
      './model_defs/topology_builder/**/*.rb',
      './exe/**/*.rb'
    ]
  end
rescue LoadError
  task :yard do
    warn 'YARD is disabled'
  end
end

CLOBBER.include("#{NETOVIZ_DIR}/*linkdown*.json")
CLEAN.include('**/*~')
