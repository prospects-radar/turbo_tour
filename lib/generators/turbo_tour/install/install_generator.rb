# frozen_string_literal: true

module TurboTour
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Installs TurboTour configuration and example journeys, then wires the shared Stimulus controller from the gem."

      def create_config_directory
        empty_directory "config/turbo_tours"
      end

      def copy_initializer
        template "turbo_tour.rb", "config/initializers/turbo_tour.rb"
      end

      def copy_example_journeys
        template "example.yml", "config/turbo_tours/example.yml"
      end

      def verify_importmap
        @importmap_available = File.exist?("config/importmap.rb")
        return if @importmap_available

        say_status(:skipped, "config/importmap.rb not found. TurboTour expects an importmap-based Stimulus setup.", :yellow)
      end

      def register_stimulus_controller
        return if @importmap_available == false

        index_path = "app/javascript/controllers/index.js"

        unless File.exist?(index_path)
          say_status(:skipped, "#{index_path} not found. Register turbo-tour manually.", :yellow)
          return
        end

        contents = File.binread(index_path)

        if contents.include?("eagerLoadControllersFrom") || contents.include?("lazyLoadControllersFrom")
          say_status(:identical, "#{index_path} already auto-loads controllers from importmap", :blue)
          return
        end

        if contents.include?('application.register("turbo-tour"')
          say_status(:identical, "#{index_path} already registers turbo-tour", :blue)
          return
        end

        import_line = %(import TurboTourController from "controllers/turbo_tour_controller")
        registration = %(application.register("turbo-tour", TurboTourController))
        anchor_pattern = /^import \{ application \} from "(controllers\/application|\.\/application)"\s*$/

        updated = if contents.match?(anchor_pattern)
          contents.sub(anchor_pattern) { |line| "#{line}\n#{import_line}" }
        else
          "#{import_line}\n#{contents}"
        end

        updated = "#{updated.rstrip}\n\n#{registration}\n"
        File.binwrite(index_path, updated)
      end

      def show_next_steps
        say_status(:ready, 'Render <%= turbo_tour "dashboard_intro" %> around your tour markup and add data-tour-step targets to your view.', :green)
        say_status(:ready, "Run rails generate turbo_tour:install:views if you want a local copy of the default tooltip partial to style.", :green)
      end
    end
  end
end
