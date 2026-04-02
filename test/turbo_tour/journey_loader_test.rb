# frozen_string_literal: true

require "test_helper"

class TurboTourJourneyLoaderTest < ActiveSupport::TestCase
  test "loads and normalizes journeys from yaml files" do
    with_temporary_directory do |root|
      write_file(root.join("config/turbo_tours/dashboard.yml"), <<~YAML)
        journeys:
          dashboard_intro:
            - name: create_project
              target: create-project
              title: Create your first project
              body: Click here to begin.
      YAML

      loader = TurboTour::JourneyLoader.new(configuration: TurboTour.configuration, root: root)

      assert_equal(
        [
          {
            "name" => "create_project",
            "target" => "create-project",
            "title" => "Create your first project",
            "body" => "Click here to begin."
          }
        ],
        loader.fetch(:dashboard_intro)
      )
      assert_equal ["dashboard_intro"], loader.all.keys
    end
  end

  test "slice returns only the requested journeys" do
    with_temporary_directory do |root|
      write_file(root.join("config/turbo_tours/journeys.yml"), <<~YAML)
        journeys:
          dashboard_intro:
            - name: create_project
              target: create-project
              title: Create your first project
              body: Click here to begin.
          invite_team:
            - name: invite_button
              target: invite-button
              title: Invite your team
              body: Bring collaborators into the workspace.
      YAML

      loader = TurboTour::JourneyLoader.new(configuration: TurboTour.configuration, root: root)

      assert_equal ["invite_team"], loader.slice(%w[invite_team]).keys
    end
  end

  test "raises a clear error for duplicate journeys" do
    with_temporary_directory do |root|
      write_file(root.join("config/turbo_tours/one.yml"), <<~YAML)
        journeys:
          dashboard_intro:
            - name: create_project
              target: create-project
              title: Create your first project
              body: Click here to begin.
      YAML

      write_file(root.join("config/turbo_tours/two.yml"), <<~YAML)
        journeys:
          dashboard_intro:
            - name: dashboard_metrics
              target: dashboard-metrics
              title: Track performance
              body: Follow your metrics here.
      YAML

      loader = TurboTour::JourneyLoader.new(configuration: TurboTour.configuration, root: root)
      error = assert_raises(TurboTour::JourneyLoader::DuplicateJourneyError) { loader.all }

      assert_match(/dashboard_intro/, error.message)
    end
  end

  test "raises a clear error when a step is missing required keys" do
    with_temporary_directory do |root|
      write_file(root.join("config/turbo_tours/invalid.yml"), <<~YAML)
        journeys:
          dashboard_intro:
            - name: create_project
              target: create-project
              title:
              body: Click here to begin.
      YAML

      loader = TurboTour::JourneyLoader.new(configuration: TurboTour.configuration, root: root)
      error = assert_raises(TurboTour::JourneyLoader::InvalidJourneyError) { loader.all }

      assert_match(/missing title/, error.message)
    end
  end

  test "raises a clear error for unknown journeys" do
    with_temporary_directory do |root|
      loader = TurboTour::JourneyLoader.new(configuration: TurboTour.configuration, root: root)
      error = assert_raises(TurboTour::JourneyLoader::InvalidJourneyError) { loader.fetch(:missing) }

      assert_match(/Unknown TurboTour journey/, error.message)
    end
  end

  test "loads locale-keyed content from locale subdirectories" do
    with_i18n_available_locales([:en, :es]) do
      with_temporary_directory do |root|
        write_file(root.join("config/turbo_tours/en/welcome.yml"), <<~YAML)
          journeys:
            welcome:
              - name: greeting
                target: greeting-banner
                title: Welcome
                body: Let us show you around.
        YAML

        write_file(root.join("config/turbo_tours/es/welcome.yml"), <<~YAML)
          journeys:
            welcome:
              - name: greeting
                target: greeting-banner
                title: Bienvenido
                body: Permítanos mostrarle el lugar.
        YAML

        loader = TurboTour::JourneyLoader.new(configuration: TurboTour.configuration, root: root)
        step = loader.fetch(:welcome).first

        assert_equal({ "en" => "Welcome", "es" => "Bienvenido" }, step["title"])
        assert_equal({ "en" => "Let us show you around.", "es" => "Permítanos mostrarle el lugar." }, step["body"])
      end
    end
  end

  test "root-level and locale-subdir journeys coexist" do
    with_i18n_available_locales([:en, :es]) do
      with_temporary_directory do |root|
        write_file(root.join("config/turbo_tours/dashboard.yml"), <<~YAML)
          journeys:
            dashboard_intro:
              - name: create_project
                target: create-project
                title: Create your first project
                body: Click here to begin.
        YAML

        write_file(root.join("config/turbo_tours/en/welcome.yml"), <<~YAML)
          journeys:
            welcome:
              - name: greeting
                target: greeting-banner
                title: Welcome
                body: Let us show you around.
        YAML

        write_file(root.join("config/turbo_tours/es/welcome.yml"), <<~YAML)
          journeys:
            welcome:
              - name: greeting
                target: greeting-banner
                title: Bienvenido
                body: Permítanos mostrarle el lugar.
        YAML

        loader = TurboTour::JourneyLoader.new(configuration: TurboTour.configuration, root: root)

        assert_equal "Create your first project", loader.fetch(:dashboard_intro).first["title"]
        assert_equal({ "en" => "Welcome", "es" => "Bienvenido" }, loader.fetch(:welcome).first["title"])
      end
    end
  end

  test "raises error for duplicate journey within the same locale subdir" do
    with_i18n_available_locales([:en]) do
      with_temporary_directory do |root|
        write_file(root.join("config/turbo_tours/en/one.yml"), <<~YAML)
          journeys:
            welcome:
              - name: greeting
                target: greeting-banner
                title: Welcome
                body: Hello.
        YAML

        write_file(root.join("config/turbo_tours/en/two.yml"), <<~YAML)
          journeys:
            welcome:
              - name: greeting
                target: greeting-banner
                title: Hi there
                body: Hey.
        YAML

        loader = TurboTour::JourneyLoader.new(configuration: TurboTour.configuration, root: root)
        error = assert_raises(TurboTour::JourneyLoader::DuplicateJourneyError) { loader.all }

        assert_match(/welcome/, error.message)
        assert_match(/locale/, error.message)
      end
    end
  end

  test "raises error when step counts differ across locales" do
    with_i18n_available_locales([:en, :es]) do
      with_temporary_directory do |root|
        write_file(root.join("config/turbo_tours/en/welcome.yml"), <<~YAML)
          journeys:
            welcome:
              - name: step_one
                target: step-one
                title: Hello
                body: Body one.
              - name: step_two
                target: step-two
                title: Next
                body: Body two.
        YAML

        write_file(root.join("config/turbo_tours/es/welcome.yml"), <<~YAML)
          journeys:
            welcome:
              - name: step_one
                target: step-one
                title: Hola
                body: Cuerpo uno.
        YAML

        loader = TurboTour::JourneyLoader.new(configuration: TurboTour.configuration, root: root)
        error = assert_raises(TurboTour::JourneyLoader::InvalidJourneyError) { loader.all }

        assert_match(/welcome/, error.message)
        assert_match(/steps/, error.message)
      end
    end
  end

  test "raises error when journey is defined in both root and locale directories" do
    with_i18n_available_locales([:en]) do
      with_temporary_directory do |root|
        write_file(root.join("config/turbo_tours/welcome.yml"), <<~YAML)
          journeys:
            welcome:
              - name: greeting
                target: greeting-banner
                title: Welcome
                body: Hello.
        YAML

        write_file(root.join("config/turbo_tours/en/welcome.yml"), <<~YAML)
          journeys:
            welcome:
              - name: greeting
                target: greeting-banner
                title: Welcome
                body: Hello.
        YAML

        loader = TurboTour::JourneyLoader.new(configuration: TurboTour.configuration, root: root)
        error = assert_raises(TurboTour::JourneyLoader::DuplicateJourneyError) { loader.all }

        assert_match(/welcome/, error.message)
        assert_match(/root and locale/, error.message)
      end
    end
  end

  test "preserves optional size key on steps" do
    with_temporary_directory do |root|
      write_file(root.join("config/turbo_tours/sized.yml"), <<~YAML)
        journeys:
          sized_tour:
            - name: big_step
              target: big-panel
              title: A wide step
              body: This step is wider.
              size: wide
      YAML

      loader = TurboTour::JourneyLoader.new(configuration: TurboTour.configuration, root: root)
      step = loader.fetch(:sized_tour).first

      assert_equal "wide", step["size"]
    end
  end

  test "non-locale subdirectory is treated as root-level file" do
    with_i18n_available_locales([:en]) do
      with_temporary_directory do |root|
        write_file(root.join("config/turbo_tours/admin/dashboard.yml"), <<~YAML)
          journeys:
            admin_dashboard:
              - name: overview
                target: overview-panel
                title: Admin overview
                body: See all the stats.
        YAML

        loader = TurboTour::JourneyLoader.new(configuration: TurboTour.configuration, root: root)
        step = loader.fetch(:admin_dashboard).first

        assert_equal "Admin overview", step["title"]
      end
    end
  end
end
