# frozen_string_literal: true

require "test_helper"
require "generators/turbo_tour/install/install_generator"

class TurboTourInstallGeneratorTest < Rails::Generators::TestCase
  tests TurboTour::Generators::InstallGenerator
  destination File.expand_path("../tmp/install_generator", __dir__)

  setup :prepare_destination

  test "creates configuration files and registers the controller when manual registration is needed" do
    write_destination_file("config/importmap.rb", "# importmap\n")
    write_destination_file("app/javascript/controllers/index.js", %(import { application } from "controllers/application"\n))

    run_generator_inside_destination

    assert_file "config/initializers/turbo_tour.rb", /config\.highlight_classes = ""/
    assert_file "config/initializers/turbo_tour.rb", /config\.skippable = true/
    assert_file "config/turbo_tours/example.yml", /dashboard_intro/
    assert_file "app/javascript/controllers/index.js", /controllers\/turbo_tour_controller/
    assert_file "app/javascript/controllers/index.js", /application\.register\("turbo-tour", TurboTourController\)/
  end

  test "does not modify controller registration when the app already eager loads controllers" do
    write_destination_file("config/importmap.rb", "# importmap\n")
    write_destination_file(
      "app/javascript/controllers/index.js",
      <<~JS
        import { application } from "controllers/application"
        import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"

        eagerLoadControllersFrom("controllers", application)
      JS
    )

    run_generator_inside_destination

    assert_file "app/javascript/controllers/index.js", /eagerLoadControllersFrom/
    assert_no_match(/application\.register\("turbo-tour"/, File.read(File.join(destination_root, "app/javascript/controllers/index.js")))
  end

  private

  def write_destination_file(relative_path, contents)
    path = File.join(destination_root, relative_path)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, contents)
  end

  def run_generator_inside_destination
    Dir.chdir(destination_root) { run_generator }
  end
end
