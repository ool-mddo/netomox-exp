# frozen_string_literal: true

source 'https://rubygems.org'

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

group :production do
  gem 'hashie', '>= 4.1.0'
  gem 'httpclient', '>= 2.8.3'
  gem 'ipaddress', '~> 0.8.3'
  gem 'netomox', github: 'corestate55/netomox', branch: 'develop'
  gem 'rake', '>= 13.0.6'
  gem 'rexml', '>= 3.2.5' # to resolve dependency of termcolor in netomox/diff_view
  gem 'test-unit', '>= 3.5.3'
  gem 'thor', '~> 1.2.1'
end

group :development do
  gem 'rubocop', '>= 0.80'
  gem 'rubocop-rake', require: false
  gem 'yard', '>= 0.9.20'
end
