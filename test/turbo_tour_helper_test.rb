# frozen_string_literal: true

require "test_helper"

class TurboTourHelperTest < ActiveSupport::TestCase
  test "renders the shared controller bootstrap with configured data attributes" do
    TurboTour.configuration.highlight_classes = "tour-highlight"
    TurboTour.configuration.session_storage_key = "custom-session"
    TurboTour.configuration.skippable = false

    html = with_sample_journeys do
      view_context.turbo_tour("dashboard_intro", auto_start: false, class: "tour-root")
    end

    assert_includes html, 'class="tour-root"'
    assert_includes html, 'data-controller="turbo-tour"'
    assert_includes html, 'data-turbo-tour-journey="dashboard_intro"'
    assert_includes html, 'data-turbo-tour-auto-start="false"'
    assert_includes html, 'data-turbo-tour-highlight-classes="tour-highlight"'
    assert_includes html, 'data-turbo-tour-session-storage-key="custom-session"'
    assert_includes html, 'data-turbo-tour-skippable-default="false"'
    assert_includes html, 'data-turbo-tour-template="true"'
    assert_includes html, "data-turbo-tour-title"
  end

  test "allows skippable to be overridden for every journey in a helper root" do
    html = with_sample_journeys do
      view_context.turbo_tour("dashboard_intro", skippable: false)
    end

    assert_includes html, 'data-turbo-tour-skippable-default="false"'
  end

  test "allows skippable to be overridden per journey" do
    html = with_sample_journeys do
      view_context.turbo_tour("dashboard_intro", "invite_team", skippable: { invite_team: false })
    end

    assert_includes html, 'data-turbo-tour-skippable-default="true"'
    assert_includes html, '&quot;invite_team&quot;:false'
  end

  test "wraps block content inside the controller root" do
    html = with_sample_journeys do
      view_context.turbo_tour("dashboard_intro", auto_start: false) do
        view_context.tag.button(
          "Start tour",
          type: "button",
          data: { action: "click->turbo-tour#start", tour_journey: "dashboard_intro" }
        )
      end
    end

    assert_includes html, "Start tour"
    assert_includes html, 'data-tour-journey="dashboard_intro"'
    assert_includes html, 'data-action="click-&gt;turbo-tour#start"'
  end

  test "raises when no journey names are provided" do
    error = assert_raises(ArgumentError) { view_context.turbo_tour }

    assert_match(/Pass at least one journey name/, error.message)
  end

  private

  def sample_journeys
    <<~YAML
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
            body: Bring collaborators into your workspace.
    YAML
  end

  def view_context
    controller = ActionController::Base.new
    context = ActionView::Base.with_empty_template_cache.with_view_paths(ActionController::Base.view_paths, {}, controller)
    context.extend(TurboTourHelper)
    context.define_singleton_method(:render) do |*|
      '<div data-turbo-tour-panel><h2 data-turbo-tour-title></h2></div>'.html_safe
    end
    context
  end

  def with_sample_journeys
    with_temporary_directory do |root|
      write_file(root.join("config/turbo_tours/dashboard.yml"), sample_journeys)
      TurboTour.instance_variable_set(
        :@journey_loader,
        TurboTour::JourneyLoader.new(configuration: TurboTour.configuration, root: root)
      )

      yield
    end
  end
end
