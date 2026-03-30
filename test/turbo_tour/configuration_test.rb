# frozen_string_literal: true

require "test_helper"

class TurboTourConfigurationTest < ActiveSupport::TestCase
  test "defaults stay framework agnostic" do
    configuration = TurboTour::Configuration.new

    assert_equal "", configuration.highlight_classes
    assert_equal "turbo_tour_session_id", configuration.session_storage_key
    assert_equal true, configuration.skippable
    assert_equal "turbo_tour/tooltip", configuration.tooltip_partial
    assert_includes configuration.journey_globs, "config/turbo_tours/**/*.yml"
  end
end
