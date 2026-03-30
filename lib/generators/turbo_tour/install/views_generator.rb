# frozen_string_literal: true

module TurboTour
  module Generators
    module Install
      class ViewsGenerator < Rails::Generators::Base
        source_root File.expand_path("../../../../app/views/turbo_tour", __dir__)

        desc "Copies TurboTour's default tooltip partial into the host application for local overrides."

        def copy_tooltip_partial
          copy_file "_tooltip.html.erb", "app/views/turbo_tour/_tooltip.html.erb"
        end

        def show_next_steps
          say_status(:ready, "Style app/views/turbo_tour/_tooltip.html.erb to match your host application.", :green)
        end
      end
    end
  end
end
