# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"

require "logger"
require "tmpdir"
require "fileutils"
require "rails"
require "action_controller/railtie"
require "action_view/railtie"
require "rails/test_help"
require "rails/generators/test_case"

require_relative "../lib/turbo_tour"

TEST_APP_ROOT = Pathname.new(File.expand_path("dummy", __dir__))

class TurboTourTestApplication < Rails::Application
  config.root = TEST_APP_ROOT
  config.eager_load = false
  config.secret_key_base = "turbo-tour-test-secret"
  config.session_store :cookie_store, key: "_turbo_tour_test"
  config.consider_all_requests_local = true
  config.hosts << "www.example.com"
  config.logger = Logger.new(nil)
end

Rails.application.initialize! unless Rails.application.initialized?

module TurboTourTestSupport
  def reset_turbo_tour_configuration
    defaults = TurboTour::Configuration.new
    configuration = TurboTour.configuration

    configuration.highlight_classes = defaults.highlight_classes
    configuration.journey_globs = defaults.journey_globs.dup
    configuration.session_storage_key = defaults.session_storage_key
    configuration.skippable = defaults.skippable
    configuration.tooltip_partial = defaults.tooltip_partial

    TurboTour.reload!
  end

  def with_temporary_directory
    Dir.mktmpdir("turbo-tour-test") do |directory|
      yield Pathname.new(directory)
    end
  end

  def write_file(path, contents)
    FileUtils.mkdir_p(path.dirname)
    path.write(contents)
  end
end

class ActiveSupport::TestCase
  include TurboTourTestSupport

  setup :reset_turbo_tour_configuration
  teardown :reset_turbo_tour_configuration
end
