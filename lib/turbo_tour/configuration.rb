# frozen_string_literal: true

module TurboTour
  class Configuration
    attr_accessor :highlight_classes, :journey_globs, :session_storage_key, :skippable, :tooltip_partial

    def initialize
      @highlight_classes = ""
      @journey_globs = ["config/turbo_tours/**/*.yml", "config/turbo_tours/**/*.yaml"]
      @session_storage_key = "turbo_tour_session_id"
      @skippable = true
      @tooltip_partial = "turbo_tour/tooltip"
    end
  end
end
