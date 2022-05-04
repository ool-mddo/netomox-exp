# frozen_string_literal: true

require 'rake'
require 'rake/clean'
require 'json'
require 'httpclient'

CONFIGS_DIR = ENV.fetch('MDDO_CONFIGS_DIR', 'configs')
MODELS_DIR = ENV.fetch('MDDO_MODELS_DIR', 'models')
NETOVIZ_DIR = ENV.fetch('MDDO_NETOVIZ_MODEL_DIR', 'netoviz_model')
MODEL_DEFS_DIR = 'model_defs'
BATFISH_WRAPPER_HOST = ENV.fetch('BATFISH_WRAPPER_HOST', 'localhost:5000')
BFW_CLIENT = HTTPClient.new
BFW_CLIENT.receive_timeout = 300

MODEL_INFO = [
  {
    network: 'batfish-test-topology',
    type: :fixed,
    label: 'Test network'
  },
  {
    network: 'pushed_configs',
    snapshot: 'mddo_network',
    type: :simulation_target,
    label: 'OOL-MDDO PJ network'
  }
].freeze

task default: %i[model_dirs simulation_pattern snapshot_to_model netoviz_index netoviz_model netoviz_layout
                 netomox_diff]

desc 'Make directories for models and netoviz'
task :model_dirs do
  puts '# Make directories'
  sh "mkdir -p #{NETOVIZ_DIR}"
  sh "mkdir -p #{MODELS_DIR}"
  # clean models directory
  sh "rm -rf #{MODELS_DIR}/*"
end

def post_bfw(api_path, data)
  header = { 'Content-Type' => 'application/json' }
  body = JSON.generate(data)
  url = "http://#{BATFISH_WRAPPER_HOST}/#{api_path}"
  puts "- POST: #{url}, data=#{data}"
  BFW_CLIENT.post url, body: body, header: header
end

def find_model_info_by_network(network)
  MODEL_INFO.find { |mi| mi[:network] == network }
end

def find_all_model_info_by_network(network)
  MODEL_INFO.find_all { |mi| mi[:network] == network }
end

def find_all_model_info_by_type(*model_info_type)
  model_info = ENV['NETWORK'] ? find_all_model_info_by_network(ENV.fetch('NETWORK')) : MODEL_INFO
  model_info.find_all { |mi| model_info_type.include?(mi[:type]) }
end

desc 'Generate snapshot patterns of simulation target networks'
task :simulation_pattern do
  puts '# Generate snapshot patterns'
  opt = {}
  if ENV['OFF_NODE']
    opt['node'] = ENV.fetch('OFF_NODE', nil)
    opt['link_regexp'] = ENV.fetch('OFF_LINK_RE', nil) if ENV['OFF_LINK_RE']
  end
  find_all_model_info_by_type(:simulation_target).each do |model_info|
    post_bfw("api/networks/#{model_info[:network]}/snapshots/#{model_info[:snapshot]}/patterns", opt)
  end
end

desc 'Generate model data (csv) from snapshots'
task :snapshot_to_model do
  puts '# Generate model data'
  find_all_model_info_by_type(:fixed, :simulation_target).each do |model_info|
    post_bfw("api/networks/#{model_info[:network]}/queries", {})
  end
end

# rubocop:disable Metrics/AbcSize
def models_list
  Dir.glob("#{MODELS_DIR}/**/*/*.csv")
     .map { |csv| File.dirname(csv) }
     .sort
     .uniq
     .map { |dir| dir.gsub(%r{^#{MODELS_DIR}/}, '') }
     .map { |dir| dir.split('/') }
     .map { |names| [names[0], names[1..].join('/')] } # unsafe snapshot name (snapshot path)
     .reject { |pair| pair[1].empty? }
end
# rubocop:enable Metrics/AbcSize

def topology_file_name(network, snapshot)
  "#{network}_#{snapshot.gsub('/', '_')}.json" # convert to safe snapshot name
end

def index_label(network, snapshot, model_info)
  models_snapshot_dir = File.join(MODELS_DIR, network, snapshot)
  snapshot_pattern = File.join(models_snapshot_dir, 'snapshot_pattern.json')
  if File.exist?(snapshot_pattern)
    data = JSON.parse(File.read(snapshot_pattern))
    "#{model_info[:label]} #{data['description']}"
  else
    "#{model_info[:label]} [#{network}/#{snapshot}]"
  end
end

desc 'Generate netoviz index file'
task :netoviz_index do
  puts '# Generate netoviz index file'
  index_data = models_list.map do |network_snapshot_pair|
    network, snapshot = network_snapshot_pair
    model_info = find_model_info_by_network(network)
    {
      'file' => topology_file_name(network, snapshot),
      'label' => index_label(network, snapshot, model_info)
    }
  end
  File.write("#{NETOVIZ_DIR}/_index.json", JSON.pretty_generate(index_data))
end

desc 'Generate topology files (for netoviz)'
task :netoviz_model do
  puts '# Generate topology files'
  # clean
  sh "rm -f #{NETOVIZ_DIR}/*linkdown*.json"
  sh "rm -f #{NETOVIZ_DIR}/*drawoff*.json"

  models_list.each do |network_snapshot_pair|
    network, snapshot = network_snapshot_pair
    topo_file = File.join(NETOVIZ_DIR, topology_file_name(network, snapshot))
    sh "bundle exec ruby #{MODEL_DEFS_DIR}/mddo_trial.rb -i #{File.join(MODELS_DIR, network, snapshot)} > #{topo_file}"
  end
end

desc 'Copy netoviz layout files'
task :netoviz_layout do
  puts '# Copy netoviz layout files'
  sh "cp #{MODEL_DEFS_DIR}/layout/*.json #{NETOVIZ_DIR}"
end

def make_topology_diff(src_topology, dst_topology)
  topology_diff = File.join(NETOVIZ_DIR, "#{File.basename(dst_topology)}.diff")
  sh "bundle exec netomox diff -o #{topology_diff} #{src_topology} #{dst_topology}"
end

desc 'Generate diff data of linkdown snapshots and overwrite'
task :netomox_diff do
  puts '# Generate diff data'
  # clean
  sh "rm -f #{NETOVIZ_DIR}/*.diff"

  find_all_model_info_by_type(:simulation_target).each do |model_info|
    network = model_info[:network]
    orig_snapshot = model_info[:snapshot]
    orig_topology = File.join(NETOVIZ_DIR, "#{network}_#{orig_snapshot}.json")
    src_topology = orig_topology

    # drawoff if exists
    drawoff_topology = File.join(NETOVIZ_DIR, "#{network}_#{orig_snapshot}_drawoff.json")
    if File.exist?(drawoff_topology)
      make_topology_diff(orig_topology, drawoff_topology)
      src_topology = drawoff_topology
    end

    # linkdown
    Dir.glob("#{NETOVIZ_DIR}/#{network}_#{orig_snapshot}_linkdown*.json").each do |linkdown_topology|
      make_topology_diff(src_topology, linkdown_topology)
    end

    # overwrite diff files
    Dir.glob("#{NETOVIZ_DIR}/*.diff").each do |topology_diff|
      sh "mv #{topology_diff} #{topology_diff.gsub(File.extname(topology_diff), '')}"
    end
  end
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
