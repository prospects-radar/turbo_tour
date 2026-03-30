# frozen_string_literal: true

require "json"
require "yaml"

require "turbo_tour/version"
require "turbo_tour/configuration"
require "turbo_tour/journey_loader"
require "turbo_tour/engine"

module TurboTour
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def journeys
      journey_loader.all
    end

    def fetch_journey(name)
      journey_loader.fetch(name)
    end

    def slice_journeys(names)
      journey_loader.slice(Array(names))
    end

    def reload!
      @journey_loader = JourneyLoader.new(configuration: configuration)
    end

    def journey_loader
      @journey_loader ||= JourneyLoader.new(configuration: configuration)
    end
  end
end
