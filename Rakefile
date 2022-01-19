# frozen_string_literal: true

require 'rake'
require 'rake/clean'
require 'json'

CONFIGS_DIR = 'configs'
MODEL_DEFS_DIR = 'model_defs'
MODELS_DIR = 'models'
NETOVIZ_DIR = 'netoviz_model'
BATFISH_HOST = ENV['BATFISH_HOST'] || 'localhost'

MODEL_INFO = [
  {
    name: 'mddo',
    type: :standalone,
    script: "#{MODEL_DEFS_DIR}/mddo.rb",
    file: 'mddo.json',
    label: 'OOL-MDDO PJ Trial (1)'
  },
  {
    name: 'batfish-test-topology',
    type: :mddo_trial,
    label: 'OOL-MDDO PJ Trial (2)'
  },
  {
    name: 'pushed_configs',
    type: :mddo_trial,
    label: 'OOL-MDDO Network'
  },
  {
    name: 'pushed_configs_linkdown',
    type: :mddo_trial_linkdown,
    src_config_name: 'pushed_configs',
    label: 'OOL-MDDO Network (LINKDOWN)'
  }
].freeze

task default: %i[make_dirs linkdown_snapshots bf_snapshots snapshot_to_model netoviz_index netoviz_models netomox_diff
                 netoviz_layouts]

desc 'Make directories for models and netoviz'
task :make_dirs do
  # sh 'docker-compose up -d'
  sh "mkdir -p #{NETOVIZ_DIR}"
  sh "mkdir -p #{MODELS_DIR}"
end

def model_info_list(*types)
  list = MODEL_INFO
  list = MODEL_INFO.find_all { |mi| mi[:name] == ENV['MODEL_NAME'] } if ENV['MODEL_NAME']
  list = list.find_all { |mi| types.include?(mi[:type]) } unless types.empty?
  list
end

def src_model_info(model_info)
  # NOTICE: Use unfiltered MODEL_INFO to find src_config_name
  MODEL_INFO.find { |m| m[:name] == model_info[:src_config_name] }
end

def src_config_name(model_info)
  src_model_info(model_info)[:name]
end

def snapshot_path(src_base, src, dst_base, dst)
  src_dir = File.join(src_base, src)
  dst_dir = File.join(dst_base, dst)
  if Dir.exist?(dst_dir)
    warn "# clean dst dir: #{dst_dir}"
    sh "rm -rf #{dst_dir}"
  end
  [src_dir, dst_dir]
end

desc 'Generate linkdown snapshots'
task :linkdown_snapshots do
  model_info_list(:mddo_trial_linkdown).each do |mi|
    src_dir, dst_dir = snapshot_path(CONFIGS_DIR, src_config_name(mi), CONFIGS_DIR, mi[:name])
    sh "python3 #{CONFIGS_DIR}/make_linkdown_snapshots.py -i #{src_dir} -o #{dst_dir}"
  end
end

desc 'Register snapshots to batfish'
task :bf_snapshots do
  model_info_list(:mddo_trial, :mddo_trial_linkdown).each do |mi|
    src_dir = File.join(CONFIGS_DIR, mi[:name])
    sh "python3 #{CONFIGS_DIR}/register_snapshots.py -b #{BATFISH_HOST} -n #{mi[:name]} -i #{src_dir}"
  end
end

desc 'Generate model data (csv) from snapshots'
task :snapshot_to_model do
  model_info_list(:mddo_trial, :mddo_trial_linkdown).each do |mi|
    sh "python3 #{CONFIGS_DIR}/exec_queries.py -b #{BATFISH_HOST} -n #{mi[:name]}"
  end
end

def snapshot_dir_name(file, dir)
  File.dirname(file).gsub(dir, '').gsub(%r{^/}, '')
end

def topology_file_name(name, file, dir)
  "#{name}_#{snapshot_dir_name(file, dir).gsub('/', '_')}.json"
end

def model_dir_files(model_info, src_dir)
  file_name = model_info[:type] == :mddo_trial_linkdown ? 'snapshot_info.json' : 'edges_layer1.csv'
  Dir.glob("#{src_dir}/**/#{file_name}").sort
end

# @param [Hash] model_info An element of MODEL_INFO
# @param [String] src_dir Base directory of csv data
# @param [String] file Files in snapshot directory (to specify model dir for a snapshot)
# @return [Hash] netoviz index datum
def netoviz_index_datum(model_info, src_dir, file)
  if model_info[:type] == :mddo_trial
    sdir = snapshot_dir_name(file, src_dir)
    topo_file = topology_file_name(model_info[:name], file, src_dir)
    label = "#{model_info[:label]}: #{sdir}"
    return { 'file' => topo_file, 'label' => label }
  end
  # when model_info[:type] == :mddo_trial_linkdown
  topo_file = topology_file_name(model_info[:name], file, src_dir)
  info = JSON.parse(File.read(file))
  label = "#{model_info[:label]}: #{info['description']}"
  { 'file' => topo_file, 'label' => label }
end

desc 'Generate netoviz index file'
task :netoviz_index do
  # Use unfiltered MODEL_INFO (make full-size index always)
  index_data = MODEL_INFO.map do |mi|
    case mi[:type]
    when :standalone
      { 'file' => mi[:file], 'label' => mi[:label] }
    when :mddo_trial, :mddo_trial_linkdown
      src_dir = File.join(MODELS_DIR, mi[:name])
      model_dir_files(mi, src_dir).map { |file| netoviz_index_datum(mi, src_dir, file) }
    else
      warn "Error: Unknown model-info type: #{mi[:type]}"
      exit 1
    end
  end
  File.write("#{NETOVIZ_DIR}/_index.json", JSON.pretty_generate(index_data.flatten))
end

desc 'Generate topology file (for netoviz)'
task :netoviz_models do
  # clean
  sh "rm -f #{NETOVIZ_DIR}/*linkdown*.json"

  model_info_list.each do |mi|
    case mi[:type]
    when :standalone
      sh "bundle exec ruby #{mi[:script]} > #{NETOVIZ_DIR}/#{mi[:file]}"
    when :mddo_trial, :mddo_trial_linkdown
      src_dir = File.join(MODELS_DIR, mi[:name])
      model_dir_files(mi, src_dir).map do |file|
        topo_file = File.join(NETOVIZ_DIR, topology_file_name(mi[:name], file, src_dir))
        sh "bundle exec ruby #{MODEL_DEFS_DIR}/mddo_trial.rb -i #{File.dirname(file)} > #{topo_file}"
      end
    else
      warn "Error: Unknown model-info type: #{mi[:type]}"
      exit 1
    end
  end
end

desc 'Copy netoviz layout files'
task :netoviz_layouts do
  sh "cp #{MODEL_DEFS_DIR}/layout/*.json #{NETOVIZ_DIR}"
end

desc 'Generate diff data of linkdown snapshots and overwrite'
task :netomox_diff do
  model_info_list(:mddo_trial_linkdown).each do |dst_mi|
    # clean
    sh "rm -f #{NETOVIZ_DIR}/*.diff"

    src_mi = src_model_info(dst_mi)
    src_dir = File.join(MODELS_DIR, src_mi[:name])
    # NOTE: choice one snapshot (head)
    csv_file = Dir.glob("#{src_dir}/**/edges_layer1.csv").shift
    src_file = File.join(NETOVIZ_DIR, topology_file_name(src_mi[:name], csv_file, src_dir))

    dst_dir = File.join(MODELS_DIR, dst_mi[:name])
    model_dir_files(dst_mi, dst_dir).map do |file|
      dst_file = File.join(NETOVIZ_DIR, topology_file_name(dst_mi[:name], file, dst_dir))
      dst_file_tmp = "#{dst_file}.diff"
      warn "# src file: #{src_file}"
      warn "# dst file: #{dst_file}"
      sh "bundle exec netomox diff -o #{dst_file_tmp} #{src_file} #{dst_file}"
      sh "mv #{dst_file_tmp} #{dst_file}" # overwrite
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
