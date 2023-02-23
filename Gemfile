# frozen_string_literal: true

source 'https://rubygems.org'

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

group :production do
  gem 'grape', '>= 1.7.0'
  gem 'hashie', '>= 4.1.0'
  gem 'httpclient', '>= 2.8.3'
  gem 'ipaddress', '~> 0.8.3'
  gem 'netomox', github: 'ool-mddo/netomox', tag: 'v0.2.0'
  gem 'parallel', '>= 1.22.1'
  gem 'rack', '>= 1.3.0', '< 3' # grape restriction
  gem 'rake', '>= 13.0.6'
  gem 'rexml', '>= 3.2.5' # to resolve dependency of termcolor in netomox/diff_view
  gem 'test-unit', '>= 3.5.3'
  gem 'thor', '~> 1.2.1'
  gem 'webrick', '~> 1.7.0' # yard restriction
end

group :development do
  gem 'rerun', '>= 0.14.0'
  gem 'rubocop', '>= 0.80'
  gem 'rubocop-rake', require: false
  gem 'yard', '>= 0.9.20'
end
