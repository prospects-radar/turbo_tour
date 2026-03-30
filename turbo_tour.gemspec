require_relative "lib/turbo_tour/version"

Gem::Specification.new do |spec|
  homepage = ENV["TURBO_TOUR_HOMEPAGE"] || "https://turbo-tour.dhairyagabhawala.com"
  source_code_uri = ENV["TURBO_TOUR_SOURCE_CODE_URI"] || "https://github.com/dhairyagabha/turbo_tour"
  changelog_uri = ENV["TURBO_TOUR_CHANGELOG_URI"] || "https://github.com/dhairyagabha/turbo_tour/blob/main/CHANGELOG.md"

  spec.name = "turbo_tour"
  spec.version = TurboTour::VERSION
  spec.authors = ["Dhairya Gabhawala"]
  spec.email = ["gabhawaladhairya@gmail.com"]

  spec.summary = "Lean onboarding tours for Rails apps built with Turbo and Stimulus."
  spec.description = "Turbo Tour provides YAML-defined onboarding journeys, a single shared Stimulus controller, and a framework-agnostic tooltip surface for Rails applications."
  spec.homepage = homepage if homepage
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["homepage_uri"] = homepage if homepage
  spec.metadata["source_code_uri"] = source_code_uri if source_code_uri
  spec.metadata["changelog_uri"] = changelog_uri if changelog_uri
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.glob("{app,config,lib}/**/*", File::FNM_DOTMATCH)
                  .reject { |path| File.directory?(path) }
                  .concat(%w[CHANGELOG.md LICENSE.md README.md turbo_tour.gemspec])
                  .uniq
  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 7.0", "< 9.0"
  spec.add_dependency "stimulus-rails", ">= 1.3", "< 2.0"

  spec.add_development_dependency "bundler", ">= 2.4", "< 3.0"
  spec.add_development_dependency "rake", ">= 13.0", "< 14.0"
end
