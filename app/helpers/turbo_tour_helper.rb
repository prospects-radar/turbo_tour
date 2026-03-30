# frozen_string_literal: true

require "active_support/core_ext/hash/keys"

module TurboTourHelper
  def turbo_tour(*journey_names, auto_start: true, partial: TurboTour.configuration.tooltip_partial,
                 highlight_classes: TurboTour.configuration.highlight_classes,
                 session_storage_key: TurboTour.configuration.session_storage_key,
                 skippable: TurboTour.configuration.skippable, **html_options, &block)
    names = Array(journey_names).flatten.compact.map(&:to_s)
    raise ArgumentError, "Pass at least one journey name to turbo_tour" if names.empty?

    default_journey = names.first
    data_attributes = (html_options.delete(:data) || {}).stringify_keys

    data_attributes["controller"] = [data_attributes["controller"], "turbo-tour"].compact.join(" ")
    data_attributes["turbo-tour-journey"] ||= default_journey
    data_attributes["turbo-tour-journeys"] = JSON.generate(TurboTour.slice_journeys(names))
    data_attributes["turbo-tour-auto-start"] = auto_start
    data_attributes["turbo-tour-highlight-classes"] = highlight_classes
    data_attributes["turbo-tour-session-storage-key"] = session_storage_key

    skippable_default, skippable_map = normalize_skippable(names, skippable)
    data_attributes["turbo-tour-skippable-default"] = skippable_default
    data_attributes["turbo-tour-skippable-map"] = JSON.generate(skippable_map) if skippable_map.any?

    html_options[:data] = data_attributes

    content_tag(:div, **html_options) do
      safe_join(
        [
          (capture(&block) if block_given?),
          tag.template(data: { turbo_tour_template: true }) do
            render partial: partial, locals: { journey_name: default_journey, journey_names: names }
          end
        ].compact
      )
    end
  end

  private

  def normalize_skippable(names, skippable)
    return [boolean_option(skippable), {}] unless skippable.is_a?(Hash)

    default = skippable.key?(:default) ? boolean_option(skippable[:default]) :
      skippable.key?("default") ? boolean_option(skippable["default"]) :
      TurboTour.configuration.skippable

    mappings = skippable.each_with_object({}) do |(journey_name, value), memo|
      key = journey_name.to_s
      next if key == "default" || !names.include?(key)

      memo[key] = boolean_option(value)
    end

    [default, mappings]
  end

  def boolean_option(value)
    value != false && !value.nil?
  end
end
