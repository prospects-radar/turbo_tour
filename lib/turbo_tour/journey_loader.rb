# frozen_string_literal: true

require "active_support/core_ext/hash/keys"
require "active_support/core_ext/object/blank"
require "pathname"

module TurboTour
  class JourneyLoader
    class Error < StandardError; end
    class DuplicateJourneyError < Error; end
    class InvalidJourneyError < Error; end

    REQUIRED_STEP_KEYS = %w[name target title body].freeze

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
      journey_files.each_with_object({}) do |file_path, journeys|
        merge_file!(journeys, file_path)
      end
    end

    def journey_files
      configuration.journey_globs.flat_map do |pattern|
        Dir.glob(root.join(pattern).to_s)
      end.sort.uniq
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

      normalized.merge(
        "name" => normalized["name"].to_s,
        "target" => normalized["target"].to_s,
        "title" => normalized["title"].to_s,
        "body" => normalized["body"].to_s
      )
    end

    def self.rails_root
      defined?(Rails) && Rails.respond_to?(:root) ? Rails.root : Pathname.new(Dir.pwd)
    end
  end
end
