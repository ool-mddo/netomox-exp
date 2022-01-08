# frozen_string_literal: true

require 'rake'
require 'json'
require 'fileutils'

CONFIGS_DIR = 'configs'
MODEL_DEFS_DIR = 'model_defs'
MODELS_DIR = 'models'
NETOVIZ_DIR = 'netoviz_model'
BATFISH_HOST = ENV['BATFISH_HOST'] || 'localhost'

MODEL_MAP = [
  {
    name: "mddo",
    type: :standalone,
    script: "#{MODEL_DEFS_DIR}/mddo.rb",
    file: 'mddo.json',
    label: 'OOL-MDDO PJ Trial (1)',
  },
  {
    name: "batfish-test-topology",
    type: :mddo_trial,
    label: 'OOL-MDDO PJ Trial'
  },
  {
    name: "pushed_configs",
    type: :mddo_trial,
    label: 'OOL-MDDO Network'
  },
  {
    name: "pushed_configs_linkdown",
    type: :mddo_trial_linkdown,
    src_config_name: "pushed_configs",
    label: 'OOL-MDDO Network (LINKDOWN)'
  }
].freeze

def src_config_name(model_info)
  MODEL_MAP.find { |m| m[:name] == model_info[:src_config_name] }[:name]
end

task :linkdown_snapshots do
  MODEL_MAP.find_all { |m| m[:type] == :mddo_trial_linkdown }.each do |mm|
    src_dir = File.join(CONFIGS_DIR, src_config_name(mm))
    dst_dir = File.join(CONFIGS_DIR, mm[:name])
    puts "# src dir = #{src_dir}"
    puts "# dst dir = #{dst_dir}"
    if Dir.exist?(dst_dir)
      puts "# clean dst dir: #{dst_dir}"
      FileUtils.rm_rf(dst_dir)
    end
    sh "python #{CONFIGS_DIR}/make_linkdown_snapshots.py -i #{src_dir} -o #{dst_dir}"
  end
end

task :snapshot_to_model do
  MODEL_MAP.find_all { |m| %i[mddo_trial mddo_trial_linkdown].include?(m[:type]) }.each do |mm|
    src_dir = File.join(CONFIGS_DIR, mm[:name])
    dst_dir = File.join(MODELS_DIR, mm[:name])
    puts "# src dir = #{src_dir}"
    puts "# dst dir = #{dst_dir}"
    if Dir.exist?(dst_dir)
      puts"# clean dst dir: #{dst_dir}"
      FileUtils.rm_rf(dst_dir)
    end
    sh "python #{CONFIGS_DIR}/exec_queries.py -b #{BATFISH_HOST} -n #{mm[:name]} -i #{src_dir} -o #{dst_dir}"
  end
end
