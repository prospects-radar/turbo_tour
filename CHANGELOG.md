# Changelog

All notable changes to this project will be documented in this file.

## [0.1.0] - 2026-03-30

Initial public release of Turbo Tour.

### Added

- Rails engine integration for guided onboarding tours in Rails applications
- YAML-defined journeys loaded from `config/turbo_tours`
- One shared Stimulus controller for multiple journeys on the same page
- Targeting through `data-tour-step` and journey launches through `data-tour-journey`
- Helper-based rendering with support for auto-start and manual launch flows
- Browser runtime API with `TurboTour.start(...)`
- Runtime extension hooks including per-journey completion handling
- DOM analytics events for start, next, previous, complete, and skip
- Non-skippable tour support for required flows
- Framework-agnostic default tooltip partial with host-app override support
- Installer generators for base setup and tooltip view overrides
- Importmap-based controller consumption from the gem without copying JavaScript into the host app

### Documentation

- Full README covering installation, YAML structure, targeting, configuration, styling, events, and release flow
- Standalone documentation site with guides, reference examples, and interactive demos

### Quality

- Test coverage for configuration, journey loading, helper rendering, and generators
- GitHub Actions CI workflow for test and build verification
- GitHub Actions release workflow for automated RubyGems publishing on GitHub release
