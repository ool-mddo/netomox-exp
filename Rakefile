# frozen_string_literal: true

require 'rake'
require 'rake/clean'

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
      './lib/**/*.rb',
      './app.rb'
    ]
  end
rescue LoadError
  task :yard do
    warn 'YARD is disabled'
  end
end

begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec)
rescue LoadError
  task :spec do
    warn 'RSpec is disabled (bundle with `test` group)'
  end
end

CLEAN.include('**/*~')
