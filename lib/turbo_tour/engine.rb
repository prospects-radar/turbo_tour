# frozen_string_literal: true

module TurboTour
  class Engine < ::Rails::Engine
    engine_name "turbo_tour"

    initializer "turbo_tour.importmap", before: "importmap" do |app|
      next unless app.config.respond_to?(:importmap)

      app.config.importmap.paths << Engine.root.join("config/importmap.rb")
      app.config.importmap.cache_sweepers << Engine.root.join("app/assets/javascripts")
    end

    initializer "turbo_tour.assets" do |app|
      next unless app.config.respond_to?(:assets)

      app.config.assets.precompile += %w[controllers/turbo_tour_controller.js turbo_tour_analytics.js]
    end

    initializer "turbo_tour.i18n" do
      config.i18n.load_path += Dir[Engine.root.join("config/locales/**/*.yml")]
    end

    initializer "turbo_tour.view_helpers" do
      ActiveSupport.on_load(:action_view) do
        include ::TurboTourHelper
      end
    end

    initializer "turbo_tour.reload_journeys" do |app|
      journey_paths = TurboTour.configuration.journey_globs.flat_map do |glob|
        Dir[app.root.join(glob)]
      end

      reloader = app.config.file_watcher.new(journey_paths, app.root.join("config/turbo_tours").to_s => %w[yml yaml]) do
        TurboTour.reload!
      end

      app.reloaders << reloader

      ActiveSupport::Reloader.to_prepare do
        reloader.execute_if_updated
      end
    end
  end
end
