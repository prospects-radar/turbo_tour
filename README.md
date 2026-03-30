<p align="center">
  <img src="https://raw.githubusercontent.com/dhairyagabha/turbo_tour/main/.github/assets/turbo-tour-wordmark.png" alt="Turbo Tour" width="520">
</p>

<p align="center">
  <a href="https://github.com/dhairyagabha/turbo_tour/actions/workflows/ci.yml">
    <img src="https://github.com/dhairyagabha/turbo_tour/actions/workflows/ci.yml/badge.svg" alt="Tests">
  </a>
  <a href="https://rubygems.org/gems/turbo_tour">
    <img src="https://img.shields.io/gem/v/turbo_tour.svg" alt="RubyGems version">
  </a>
</p>

<p align="center">
  <a href="https://turbo-tour.dhairyagabhawala.com">Documentation</a>
  ·
  <a href="https://turbo-tour.dhairyagabhawala.com/examples/product-tour">See the demo</a>
  ·
  <a href="https://github.com/dhairyagabha/turbo_tour/blob/main/CHANGELOG.md">Changelog</a>
  ·
  <a href="https://rubygems.org/gems/turbo_tour">RubyGems</a>
  ·
  <a href="https://github.com/dhairyagabha/turbo_tour">GitHub</a>
</p>

# Turbo Tour

`turbo_tour` is a lean Rails engine for guided onboarding tours built around Hotwire Turbo, a single Stimulus controller, YAML-defined journeys, and a framework-agnostic tooltip surface.

## Features

- Multiple journeys loaded from YAML files in `config/turbo_tours`
- One shared Stimulus controller for every tour on the page
- Targeting via `data-tour-step="..."` instead of IDs or CSS selectors
- Configurable highlight classes for any host-app CSS approach
- Default tooltip partial with semantic classes that can be overridden in the host app
- Optional non-skippable tours for flows that must be completed
- Per-journey completion hooks and lightweight runtime extensions
- DOM analytics events with session and progress metadata
- Keyboard support, focus management, and lightweight positioning

## Installation

Add the gem to your Rails app:

```ruby
gem "turbo_tour"
```

Then install it:

```bash
bundle install
bin/rails generate turbo_tour:install
```

Turbo Tour now expects the host app to use the standard Rails importmap + Stimulus setup for loading the shared controller from the gem.

The installer will:

- create `config/turbo_tours/example.yml`
- create `config/initializers/turbo_tour.rb`
- make the shared Stimulus controller available from the gem in importmap-based apps
- register the controller only when your Stimulus setup uses manual registration

If you want a local copy of the default tooltip partial to style, run:

```bash
bin/rails generate turbo_tour:install:views
```

## Define Tour Targets

Use `data-tour-step` attributes on the elements you want to spotlight:

```erb
<button data-tour-step="create-project">
  Create Project
</button>

<section data-tour-step="dashboard-metrics">
  ...
</section>
```

## How Targeting Works

Turbo Tour uses two small data attributes when you launch tours from markup:

- `data-tour-step="create-project"` marks a DOM element that a YAML step can target
- `data-tour-journey="dashboard_intro"` tells `click->turbo-tour#start` which preloaded journey to start

That means this button:

```erb
<button data-tour-step="create-project">
  Create Project
</button>
```

is resolved by this YAML step:

```yaml
- name: create_project
  target: create-project
  title: "Create your first project"
  body: "Click here to begin."
```

At runtime, Turbo Tour turns the step's `target` into the selector `[data-tour-step="create-project"]`.

## Create Journeys

Journeys live in YAML. Step order is determined by array order, so you do not need explicit indexes.

```yaml
journeys:
  dashboard_intro:
    - name: create_project
      target: create-project
      title: "Create your first project"
      body: "Click here to create your first project."

    - name: dashboard_metrics
      target: dashboard-metrics
      title: "Track performance"
      body: "This area shows your analytics metrics."

  invite_team:
    - name: invite_button
      target: invite-button
      title: "Invite your team"
      body: "Bring collaborators into your workspace."
```

Each step key has one job:

- `name` is the step identifier used in events and analytics payloads
- `target` maps to the matching `data-tour-step` value in the DOM
- `title` is the tooltip heading
- `body` is the tooltip copy

Step order comes from the YAML array order. The first item is step 1, the second item is step 2, and so on. No explicit index is needed.

## Render a Tour

Render one or more journeys into a view:

```erb
<%= turbo_tour "dashboard_intro" %>
```

To preload multiple journeys into one controller root:

```erb
<%= turbo_tour "dashboard_intro", "invite_team", auto_start: false %>
```

By default, the first journey auto-starts. Set `auto_start: false` when you want to trigger tours manually.

If a tour should not be dismissible, pass `skippable: false`:

```erb
<%= turbo_tour "security_setup", auto_start: false, skippable: false do %>
  ...
<% end %>
```

When a tour is not skippable, Turbo Tour hides the skip control and ignores the Escape key for that helper root.

If one helper root preloads several journeys, you can override skip behavior per journey:

```erb
<%= turbo_tour "dashboard_intro", "security_setup",
      auto_start: false,
      skippable: { dashboard_intro: true, security_setup: false } do %>
  ...
<% end %>
```

## Start Tours Manually

The cleanest manual-start pattern is to wrap the relevant page markup with the helper and trigger the shared controller directly:

```erb
<%= turbo_tour "dashboard_intro", auto_start: false do %>
  <button type="button" data-action="click->turbo-tour#start" data-tour-journey="dashboard_intro">
    Start tour
  </button>

  <button data-tour-step="create-project">
    Create Project
  </button>
<% end %>
```

This keeps the launch button, step targets, and tooltip template inside the same Stimulus scope without adding a second host-app controller.

Turbo Tour also exposes a browser API when you need to start a rendered journey from separate JavaScript:

```js
TurboTour.start("dashboard_intro")
```

It also exposes a completion hook API so host apps can add behavior in separate JavaScript modules instead of editing the base controller:

```js
TurboTour.onComplete("dashboard_intro", ({ detail }) => {
  window.analytics?.track("Dashboard Intro Completed", detail)
})
```

If you prefer module imports over globals, the gem-provided controller module also exports `onComplete` and `registerExtension`, so you can keep host-specific behavior in a separate file.

The helper renders one controller root for the wrapped content:

```html
<div
  data-controller="turbo-tour"
  data-turbo-tour-journey="dashboard_intro"
  ...
></div>
```

With the default Rails importmap + Stimulus setup, no controller file needs to be copied into the host app. Turbo Tour pins `controllers/turbo_tour_controller` from the gem, so `eagerLoadControllersFrom("controllers", application)` will pick it up automatically.

If your app uses manual Stimulus registration instead of eager or lazy loading, import the gem controller like this:

```js
import TurboTourController from "controllers/turbo_tour_controller"
application.register("turbo-tour", TurboTourController)
```

## Completion Hooks and Extensions

Register a reusable extension when you want grouped lifecycle behavior:

```js
TurboTour.registerExtension({
  name: "onboarding-follow-ups",
  journeys: {
    dashboard_intro: {
      onComplete() {
        window.location.assign("/projects/new")
      }
    },
    invite_team: {
      onComplete({ detail }) {
        window.app?.celebrate(detail.journey_name)
      }
    }
  }
})
```

Completion hooks receive a context object with:

- `detail`, which matches the DOM event payload
- `journeyName`, `stepName`, `stepIndex`, `totalSteps`
- `progress`, `progressPercentage`, `sessionId`
- `controller`, `target`, `panel`, `step`, and `steps`

Extensions can implement these lifecycle methods:

- `onStart`
- `onNext`
- `onPrevious`
- `onComplete`
- `onSkip`

## Multiple Journeys on the Same Page

More than one journey can exist on the same page. You can either:

- render separate helper roots for each journey
- preload several journeys into one helper root and start them by name

Every runtime path still uses the same `controllers/turbo_tour_controller` module from the gem unless the host app intentionally overrides that pin locally.

## Styling

Turbo Tour does not require Tailwind or any other CSS framework.

Highlighting is class-based so you can plug in whatever styling approach your host app already uses. The default highlight class string is empty:

```ruby
""
```

Override them in the initializer:

```ruby
TurboTour.configure do |config|
  config.highlight_classes = "is-tour-highlighted"
end
```

If your app uses utility classes, component classes, or design-system hooks, pass those classes here. Turbo Tour only adds and removes the configured class string.

You can also make tours non-skippable by default:

```ruby
TurboTour.configure do |config|
  config.skippable = false
end
```

## Override the Tooltip Partial

Turbo Tour renders `turbo_tour/tooltip`, so the host app can override it by adding:

```text
app/views/turbo_tour/_tooltip.html.erb
```

The fastest way to start from the gem's default structure is:

```bash
bin/rails generate turbo_tour:install:views
```

The shipped partial is intentionally framework-agnostic and exposes semantic classes such as:

- `turbo-tour-tooltip`
- `turbo-tour-tooltip__content`
- `turbo-tour-tooltip__title`
- `turbo-tour-tooltip__body`
- `turbo-tour-tooltip__button`

Keep these hooks in your override so the controller can populate and control the UI:

- `data-turbo-tour-panel`
- `data-turbo-tour-title`
- `data-turbo-tour-body`
- `data-turbo-tour-progress`
- `data-turbo-tour-prev`
- `data-turbo-tour-next`

Include `data-turbo-tour-skip` if you want the partial to render a skip control. Turbo Tour can run without it.

The default partial already includes the right `data-action` bindings, so host apps can copy and restyle it without reworking the controller contract.

## Analytics Events

Turbo Tour dispatches DOM events on `document`:

- `turbo-tour:start`
- `turbo-tour:next`
- `turbo-tour:previous`
- `turbo-tour:complete`
- `turbo-tour:skip-tour`

Each event includes:

```js
{
  session_id: "abc123",
  journey_name: "dashboard_intro",
  step_name: "create_project",
  step_index: 0,
  total_steps: 3,
  progress: 0.33,
  progress_percentage: 33
}
```

Example analytics hook:

```js
document.addEventListener("turbo-tour:complete", ({ detail }) => {
  window.analytics?.track("Turbo Tour Completed", detail)
})
```

Or, if the analytics call should only run for one specific journey:

```js
TurboTour.onComplete("dashboard_intro", ({ detail }) => {
  window.analytics?.track("Dashboard Intro Completed", detail)
})
```

## Accessibility

The default controller and partial provide:

- keyboard navigation with left and right arrows, plus Escape when the tour is skippable
- focus transfer into the tooltip while a tour is active
- focus restoration when the tour ends
- `role="dialog"` and ARIA labeling on the tooltip panel

## Notes

- Journeys are loaded from `config/turbo_tours/**/*.yml` and `**/*.yaml`
- Duplicate journey names across files raise an error to keep behavior deterministic
- Missing target elements are skipped so partially-rendered pages do not crash the tour

## Example

```erb
<%= turbo_tour "dashboard_intro", auto_start: false do %>
  <button type="button" data-action="click->turbo-tour#start" data-tour-journey="dashboard_intro">
    Start tour
  </button>

  <button data-tour-step="create-project">Create Project</button>
<% end %>
```

```yaml
journeys:
  dashboard_intro:
    - name: create_project
      target: create-project
      title: "Create your first project"
      body: "Click here to begin."
```