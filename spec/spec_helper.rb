# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'
require 'json'
require 'yaml'

# NOTE: NetomoxExp::TOPOLOGIES_DIR / Helpers::USECASE_DIR are fixed when the app is loaded.
#   Point them to temporary directories BEFORE requiring the app.
SPEC_TMP_ROOT = Dir.mktmpdir('netomox-exp-spec')
ENV['MDDO_QUERIES_DIR'] = File.join(SPEC_TMP_ROOT, 'queries')
ENV['MDDO_TOPOLOGIES_DIR'] = File.join(SPEC_TMP_ROOT, 'topologies')
ENV['MDDO_USECASES_DIR'] = File.join(SPEC_TMP_ROOT, 'usecases')
ENV['NETOMOX_EXP_LOG_LEVEL'] ||= 'fatal'
ENV['NETOMOX_LOG_LEVEL'] ||= 'fatal'

SPEC_ROOT = __dir__
$LOAD_PATH.unshift(File.expand_path('..', __dir__)) # `require 'lib/...'` style used in app

Dir[File.join(SPEC_ROOT, 'support', '**', '*.rb')].each { |f| require f }

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.disable_monkey_patching!
  config.order = :random
  config.after(:suite) { FileUtils.rm_rf(SPEC_TMP_ROOT) }
end
