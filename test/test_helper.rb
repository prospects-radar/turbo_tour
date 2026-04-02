# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"

require "logger"
require "tmpdir"
require "fileutils"
require "rails"
require "action_controller/railtie"
require "action_view/railtie"
require "active_record/railtie"
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

require "rails/test_help"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.define do
  create_table :turbo_tour_events, force: true do |t|
    t.string   :session_id,          null: false
    t.string   :journey_name,        null: false
    t.string   :step_name
    t.integer  :step_index
    t.integer  :total_steps
    t.string   :event_name,          null: false
    t.decimal  :progress,            precision: 3, scale: 2
    t.integer  :progress_percentage
    t.string   :reason
    t.string   :trackable_type
    t.bigint   :trackable_id
    t.string   :ip_address
    t.string   :user_agent
    t.datetime :created_at,          null: false
  end

  create_table :users, force: true do |t|
    t.string :name
  end
end

class User < ActiveRecord::Base; end

module TurboTourTestSupport
  def reset_turbo_tour_configuration
    defaults = TurboTour::Configuration.new
    configuration = TurboTour.configuration

    configuration.highlight_classes = defaults.highlight_classes
    configuration.journey_globs = defaults.journey_globs.dup
    configuration.session_storage_key = defaults.session_storage_key
    configuration.skippable = defaults.skippable
    configuration.tooltip_partial = defaults.tooltip_partial
    configuration.tooltip_size = defaults.tooltip_size
    configuration.analytics_enabled = defaults.analytics_enabled
    configuration.analytics_endpoint_path = defaults.analytics_endpoint_path
    configuration.current_user_resolver = defaults.current_user_resolver

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

  def with_i18n_available_locales(locales)
    original = I18n.available_locales
    I18n.available_locales = locales
    yield
  ensure
    I18n.available_locales = original
  end
end

class ActiveSupport::TestCase
  include TurboTourTestSupport

  setup :reset_turbo_tour_configuration
  teardown :reset_turbo_tour_configuration
end
