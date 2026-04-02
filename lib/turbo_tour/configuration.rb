# frozen_string_literal: true

module TurboTour
  class Configuration
    attr_accessor :highlight_classes, :journey_globs, :session_storage_key, :skippable, :tooltip_partial,
                  :tooltip_size, :default_locale, :analytics_enabled, :analytics_endpoint_path,
                  :current_user_resolver

    def initialize
      @highlight_classes = ""
      @journey_globs = ["config/turbo_tours/**/*.yml", "config/turbo_tours/**/*.yaml"]
      @session_storage_key = "turbo_tour_session_id"
      @skippable = true
      @tooltip_partial = "turbo_tour/tooltip"
      @tooltip_size = nil
      @default_locale = nil
      @analytics_enabled = false
      @analytics_endpoint_path = "/turbo_tour"
      @current_user_resolver = nil
    end
  end
end
