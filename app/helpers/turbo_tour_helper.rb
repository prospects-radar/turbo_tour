# frozen_string_literal: true

require "active_support/core_ext/hash/keys"

module TurboTourHelper
  def turbo_tour(*journey_names, auto_start: true, partial: TurboTour.configuration.tooltip_partial,
                 highlight_classes: TurboTour.configuration.highlight_classes,
                 session_storage_key: TurboTour.configuration.session_storage_key,
                 skippable: TurboTour.configuration.skippable,
                 locale: nil, **html_options, &block)
    names = Array(journey_names).flatten.compact.map(&:to_s)
    raise ArgumentError, "Pass at least one journey name to turbo_tour" if names.empty?

    resolved_locale = resolve_turbo_tour_locale(locale)
    default_journey = names.first
    data_attributes = (html_options.delete(:data) || {}).stringify_keys

    data_attributes["controller"] = [data_attributes["controller"], "turbo-tour"].compact.join(" ")
    data_attributes["turbo-tour-journey"] ||= default_journey
    data_attributes["turbo-tour-journeys"] = JSON.generate(
      localize_journeys(TurboTour.slice_journeys(names), resolved_locale)
    )
    data_attributes["turbo-tour-auto-start"] = auto_start
    data_attributes["turbo-tour-highlight-classes"] = highlight_classes
    data_attributes["turbo-tour-session-storage-key"] = session_storage_key
    data_attributes["turbo-tour-translations"] = JSON.generate(turbo_tour_ui_translations(resolved_locale))

    skippable_default, skippable_map = normalize_skippable(names, skippable)
    data_attributes["turbo-tour-skippable-default"] = skippable_default
    data_attributes["turbo-tour-skippable-map"] = JSON.generate(skippable_map) if skippable_map.any?

    html_options[:data] = data_attributes

    content_tag(:div, **html_options) do
      safe_join(
        [
          (capture(&block) if block_given?),
          tag.template(data: { turbo_tour_template: true }) do
            render partial: partial, locals: {
              journey_name: default_journey,
              journey_names: names,
              locale: resolved_locale
            }
          end
        ].compact
      )
    end
  end

  def turbo_tour_analytics_meta_tag
    return unless TurboTour.analytics_enabled?

    endpoint = "#{TurboTour.configuration.analytics_endpoint_path}/events"
    tag(:meta, name: "turbo-tour-analytics-url", content: endpoint)
  end

  private

  def resolve_turbo_tour_locale(explicit_locale)
    explicit_locale || TurboTour.configuration.default_locale || I18n.locale
  end

  def localize_journeys(journeys, locale)
    locale_key = locale.to_s

    journeys.transform_values do |steps|
      steps.map do |step|
        step.merge(
          "title" => resolve_localizable(step["title"], locale_key),
          "body" => resolve_localizable(step["body"], locale_key)
        )
      end
    end
  end

  def resolve_localizable(value, locale_key)
    return value unless value.is_a?(Hash)

    value[locale_key] || value.values.first || ""
  end

  def turbo_tour_ui_translations(locale)
    {
      "prev" => I18n.t("turbo_tour.prev", locale: locale),
      "next" => I18n.t("turbo_tour.next", locale: locale),
      "finish" => I18n.t("turbo_tour.finish", locale: locale),
      "skip" => I18n.t("turbo_tour.skip", locale: locale),
      "progress" => I18n.t("turbo_tour.progress", locale: locale)
    }
  end

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
