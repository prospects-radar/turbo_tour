# frozen_string_literal: true

require "test_helper"
require "generators/turbo_tour/install/views_generator"

class TurboTourInstallViewsGeneratorTest < Rails::Generators::TestCase
  tests TurboTour::Generators::Install::ViewsGenerator
  destination File.expand_path("../tmp/install_views_generator", __dir__)

  setup :prepare_destination

  test "copies the default tooltip partial into the host application" do
    run_generator

    assert_file "app/views/turbo_tour/_tooltip.html.erb", /data-turbo-tour-panel/
    assert_file "app/views/turbo_tour/_tooltip.html.erb", /turbo-tour-tooltip__button--primary/
  end
end
