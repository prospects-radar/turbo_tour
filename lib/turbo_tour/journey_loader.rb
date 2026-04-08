# frozen_string_literal: true

require "active_support/core_ext/hash/keys"
require "active_support/core_ext/object/blank"
require "pathname"

module TurboTour
  class JourneyLoader
    class Error < StandardError; end
    class DuplicateJourneyError < Error; end
    class InvalidJourneyError < Error; end

    REQUIRED_STEP_KEYS = %w[name title body].freeze

    def initialize(configuration:, root: nil)
      @configuration = configuration
      @root = root || self.class.rails_root
    end

    def all
      @all ||= load_journeys.freeze
    end

    def fetch(name)
      all.fetch(name.to_s)
    rescue KeyError
      raise InvalidJourneyError, "Unknown TurboTour journey #{name.inspect}"
    end

    def slice(names)
      Array(names).each_with_object({}) do |name, journeys|
        journeys[name.to_s] = fetch(name)
      end
    end

    private

    attr_reader :configuration, :root

    def load_journeys
      journeys = {}
      locale_groups = Hash.new { |h, k| h[k] = {} }

      journey_files.each do |file_path|
        locale = detect_locale_from_path(file_path)

        if locale
          collect_locale_file!(locale_groups, file_path, locale)
        else
          merge_file!(journeys, file_path)
        end
      end

      merge_locale_groups!(journeys, locale_groups)
      journeys
    end

    def journey_files
      configuration.journey_globs.flat_map do |pattern|
        Dir.glob(root.join(pattern).to_s)
      end.sort.uniq
    end

    def detect_locale_from_path(file_path)
      available = I18n.available_locales.map(&:to_s)
      relative = Pathname.new(file_path).relative_path_from(root)
      parts = relative.each_filename.to_a

      # Look for a locale segment among the path components (excluding the filename).
      # The first directory component that matches an available locale wins.
      parts[0...-1].each do |segment|
        return segment if available.include?(segment)
      end

      nil
    end

    def merge_file!(journeys, file_path)
      data = YAML.safe_load(File.read(file_path), aliases: false) || {}
      file_journeys = data.fetch("journeys", {})

      unless file_journeys.is_a?(Hash)
        raise InvalidJourneyError, "#{file_path} must define a top-level journeys hash"
      end

      file_journeys.each do |journey_name, steps|
        normalized_name = journey_name.to_s

        if journeys.key?(normalized_name)
          raise DuplicateJourneyError, "Journey #{normalized_name.inspect} is defined more than once"
        end

        journeys[normalized_name] = normalize_steps(steps, journey_name: normalized_name, file_path: file_path)
      end
    end

    def collect_locale_file!(locale_groups, file_path, locale)
      data = YAML.safe_load(File.read(file_path), aliases: false) || {}
      file_journeys = data.fetch("journeys", {})

      unless file_journeys.is_a?(Hash)
        raise InvalidJourneyError, "#{file_path} must define a top-level journeys hash"
      end

      file_journeys.each do |journey_name, steps|
        normalized_name = journey_name.to_s

        if locale_groups[normalized_name].key?(locale)
          raise DuplicateJourneyError,
                "Journey #{normalized_name.inspect} is defined more than once for locale #{locale.inspect}"
        end

        locale_groups[normalized_name][locale] =
          normalize_steps(steps, journey_name: normalized_name, file_path: file_path)
      end
    end

    def merge_locale_groups!(journeys, locale_groups)
      locale_groups.each do |journey_name, locales_hash|
        if journeys.key?(journey_name)
          raise DuplicateJourneyError,
                "Journey #{journey_name.inspect} is defined in both root and locale directories"
        end

        reference_locale = locales_hash.keys.sort.first
        reference_steps = locales_hash[reference_locale]

        locales_hash.each do |locale, steps|
          next if steps.length == reference_steps.length

          raise InvalidJourneyError,
                "Journey #{journey_name.inspect} has #{steps.length} steps in locale #{locale.inspect} " \
                "but #{reference_steps.length} in #{reference_locale.inspect}"
        end

        journeys[journey_name] = reference_steps.each_with_index.map do |ref_step, idx|
          title_hash = {}
          body_hash = {}

          locales_hash.sort.each do |locale, steps|
            title_hash[locale] = steps[idx]["title"]
            body_hash[locale] = steps[idx]["body"]
          end

          ref_step.merge("title" => title_hash, "body" => body_hash)
        end
      end
    end

    def normalize_steps(steps, journey_name:, file_path:)
      unless steps.is_a?(Array)
        raise InvalidJourneyError, "#{file_path} journey #{journey_name.inspect} must be an array of steps"
      end

      steps.map.with_index do |step, index|
        normalize_step(step, journey_name: journey_name, file_path: file_path, index: index)
      end
    end

    def normalize_step(step, journey_name:, file_path:, index:)
      unless step.is_a?(Hash)
        raise InvalidJourneyError, "#{file_path} journey #{journey_name.inspect} step #{index + 1} must be a hash"
      end

      normalized = step.deep_stringify_keys
      missing_keys = REQUIRED_STEP_KEYS.select { |key| normalized[key].blank? }

      if missing_keys.any?
        raise InvalidJourneyError,
              "#{file_path} journey #{journey_name.inspect} step #{index + 1} is missing #{missing_keys.join(', ')}"
      end

      result = normalized.merge(
        "name" => normalized["name"].to_s,
        "title" => normalize_localizable(normalized["title"]),
        "body" => normalize_localizable(normalized["body"])
      )
      result["target"] = normalized["target"].to_s if normalized["target"].present?

      result.tap do |step|
        step["size"] = step["size"].to_s if step.key?("size")
        step["action"] = step["action"].to_s if step.key?("action")
        step["action_target"] = step["action_target"].to_s if step.key?("action_target")
      end
    end

    def normalize_localizable(value)
      value.to_s
    end

    def self.rails_root
      defined?(Rails) && Rails.respond_to?(:root) ? Rails.root : Pathname.new(Dir.pwd)
    end
  end
end
