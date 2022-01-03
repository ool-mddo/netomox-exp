# frozen_string_literal: true

require 'rake'
require 'rake/clean'
require 'json'

NETOVIZ_MODEL_DIR = 'netoviz_model'
MODEL_MAP = [
  {
    script: 'model_defs/mddo.rb',
    file: 'mddo.json',
    label: 'OOL-MDDO PJ Trial (1)',
    type: :standalone
  },
  {
    source: 'models/batfish-test-topology/l2/sample(\\d+)',
    file: 'mddo_l2s$1.json',
    label: 'OOL-MDDO PJ Trial(2) L2 sample$1',
    type: :mddo_trial
  },
  {
    source: 'models/batfish-test-topology/l2l3/sample3',
    label: 'OOL-MDDO PJ Trial(2) L2-L3 sample3',
    file: 'mddo_l23s3.json',
    type: :mddo_trial
  },
  {
    source: 'models/batfish-test-topology/l2l3/sample3err2',
    file: 'mddo_l23s3e2.json',
    label: 'OOL-MDDO PJ Trial(2) L2-L3 sample3 Error2',
    type: :mddo_trial
  },
  {
    source: 'models/pushed_configs/mddo_network',
    label: 'OOL-MDDO PJ Experiment Network',
    file: 'mddo_network.json',
    type: :mddo_trial
  },
  {
    source: 'models/pushed_configs_linkdown/mddo_network_(\\d+)',
    file: 'mddo_network_linkdown_$1.json',
    label: 'OOL-MDDO PJ Experiment Network',
    diff_src: 'mddo_network.json',
    type: :mddo_trial
  }
].freeze

##################
# common functions

def match_dirs(path)
  Dir.glob(path.gsub(/\(.+\)/, '*')).sort
end

def match_eval(match_str, re_str, target_str)
  if target_str =~ /\$\d/ && match_str =~ Regexp.new(re_str)
    target_str.gsub(/\$1/, Regexp.last_match(1))
  else
    target_str
  end
end

##################
# task definitions

task default: %i[netoviz_model_dir netoviz_index netoviz_models netoviz_layouts diff]

desc 'pre-task'
task :netoviz_model_dir do
  sh 'configs/make_csv.sh all'
  sh "mkdir -p #{NETOVIZ_MODEL_DIR}"
end

task :netoviz_index do
  index_data = MODEL_MAP.map do |mm|
    case mm[:type]
    when :standalone
      { 'file' => mm[:file], 'label' => mm[:label] }
    when :mddo_trial
      match_dirs(mm[:source]).map do |match_dir|
        label_str = match_eval(match_dir, mm[:source], mm[:label])
        snapshot_info_path = Pathname.new(match_dir).join('snapshot_info.json')
        if File.exist?(snapshot_info_path.to_s)
          snapshot_info = JSON.parse(File.read(snapshot_info_path.to_s))
          label_str += ": #{snapshot_info['description']}"
        end
        {
          'file' => match_eval(match_dir, mm[:source], mm[:file]),
          'label' => label_str
        }
      end
    else
      warn "Error: Unknown model-map type: #{mm[:type]}"
      exit 1
    end
  end
  File.write("#{NETOVIZ_MODEL_DIR}/_index.json", JSON.pretty_generate(index_data.flatten))
end

task :netoviz_models do
  MODEL_MAP.each do |mm|
    puts "# model map = #{mm}"
    case mm[:type]
    when :standalone
      sh "bundle exec ruby #{mm[:script]} > #{NETOVIZ_MODEL_DIR}/#{mm[:file]}"
    when :mddo_trial
      match_dirs(mm[:source]).each do |match_dir|
        file = match_eval(match_dir, mm[:source], mm[:file])
        sh "bundle exec ruby model_defs/mddo_trial.rb -i #{match_dir} > #{NETOVIZ_MODEL_DIR}/#{file}"
      end
    else
      warn "Error: Unknown model-map type: #{mm[:type]}"
      exit 1
    end
  end
end

task :netoviz_layouts do
  sh "cp model_defs/layout/*.json #{NETOVIZ_MODEL_DIR}"
end

task :diff do
  MODEL_MAP.filter { |mm| mm[:diff_src] }.each do |mm|
    case mm[:type]
    when :mddo_trial
      match_dirs(mm[:source]).each do |match_dir|
        src_file = "#{NETOVIZ_MODEL_DIR}/#{mm[:diff_src]}"
        file = match_eval(match_dir, mm[:source], mm[:file])
        dst_file = "#{NETOVIZ_MODEL_DIR}/#{file}"
        dst_file_tmp = "#{dst_file}.tmp"
        sh "bundle exec netomox diff -o #{dst_file_tmp} #{src_file} #{dst_file}"
        sh "mv #{dst_file_tmp} #{dst_file}" # overwrite
      end
    else
      warn 'Warning: diff is enabled for mddo_trial type'
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
      './model_defs/mddo_trial/**/*.rb',
      './model_defs/bf_common/**/*.rb',
      './model_defs/mddo_trial*.rb',
      './exe/**/*.rb'
    ]
  end
rescue LoadError
  task :yard do
    warn 'YARD is disabled'
  end
end

CLOBBER.include("#{NETOVIZ_MODEL_DIR}/*_linkdown*.json")
CLEAN.include('**/*~')
