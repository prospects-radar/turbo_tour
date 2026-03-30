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

      app.config.assets.precompile += %w[controllers/turbo_tour_controller.js]
    end

    initializer "turbo_tour.view_helpers" do
      ActiveSupport.on_load(:action_view) do
        include ::TurboTourHelper
      end
    end

    initializer "turbo_tour.reload_journeys" do
      ActiveSupport::Reloader.to_prepare do
        TurboTour.reload!
      end
    end
  end
end
