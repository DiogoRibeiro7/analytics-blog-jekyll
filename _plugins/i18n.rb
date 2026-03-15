# frozen_string_literal: true

module Datalog
  module I18n
    module_function

    def locale(context)
      page_lang = context['page'] && context['page']['lang']
      site = context.registers[:site]
      site_locale = site.config.dig('theme_options', 'localization', 'default_locale') || site.config['locale'] || 'en'
      lang = page_lang || site_locale
      lang.to_s.split(/[-_]/).first
    end

    def data_for(site)
      site.data.fetch('i18n', {})
    end

    def lookup(site, locale_code, key)
      data = data_for(site)
      locales = [locale_code, 'en'].uniq
      path = key.to_s.split('.')

      locales.each do |code|
        scope = data[code]
        next unless scope

        value = path.reduce(scope) do |memo, segment|
          break unless memo.is_a?(Hash)

          memo[segment] || memo[segment.to_sym]
        end

        return value if value.is_a?(String)
      end

      nil
    end

    def interpolate(value, options)
      return value unless options.is_a?(Hash) && !options.empty?

      options.reduce(value) do |memo, (key, replacement)|
        memo.gsub("{{#{key}}}", replacement.to_s)
      end
    end

    def translate(context, key, options = {})
      site = context.registers[:site]
      locale_code = locale(context)
      value = lookup(site, locale_code, key)
      value = key unless value
      interpolate(value.to_s, stringify_keys(options))
    end

    def stringify_keys(options)
      return {} unless options

      options.each_with_object({}) do |(key, value), memo|
        memo[key.to_s] = value
      end
    end

    def localized_format(context, input, format_key = 'long')
      date = if input.respond_to?(:to_time)
               input.to_time
             else
               Liquid::Utils.to_date(input)
             end
      return '' unless date

      site = context.registers[:site]
      locale_code = locale(context)
      translations = data_for(site)
      locale_data = translations[locale_code] || translations['en'] || {}
      date_scope = locale_data['date'] || {}
      formats = date_scope['formats'] || {}
      format_string = formats[format_key] || formats['default'] || '%B %-d, %Y'
      formatted = date.strftime(format_string)

      months = date_scope['months'] || {}
      short_months = date_scope['months_short'] || {}
      weekdays = date_scope['weekdays'] || {}
      short_weekdays = date_scope['weekdays_short'] || {}

      formatted = replace_name(formatted, date.strftime('%B'), months[date.month.to_s] || months[date.month]) if months && !months.empty?
      formatted = replace_name(formatted, date.strftime('%b'), short_months[date.month.to_s] || short_months[date.month]) if short_months && !short_months.empty?
      formatted = replace_name(formatted, date.strftime('%A'), weekdays[date.wday.to_s] || weekdays[date.wday]) if weekdays && !weekdays.empty?
      formatted = replace_name(formatted, date.strftime('%a'), short_weekdays[date.wday.to_s] || short_weekdays[date.wday]) if short_weekdays && !short_weekdays.empty?

      formatted
    end

    def replace_name(text, english, localized)
      return text unless english && localized

      text.gsub(english, localized)
    end
  end
end

class TranslateTag < Liquid::Tag
  SYNTAX = /(\w[\w\.-]*)(.*)?/.freeze

  def initialize(tag_name, markup, tokens)
    super
    unless markup.strip =~ SYNTAX
      raise Liquid::SyntaxError, "Syntax Error in 't' - Valid syntax: t key [arg: value]"
    end

    @key = Regexp.last_match(1)
    @markup = Regexp.last_match(2)
  end

  def render(context)
    options = parse_options(@markup, context)
    Datalog::I18n.translate(context, @key, options)
  end

  private

  def parse_options(markup, context)
    return {} unless markup && !markup.strip.empty?

    tokens = markup.strip.split(',').map(&:strip)
    tokens.each_with_object({}) do |token, memo|
      next if token.empty?

      if token.include?(':')
        key, value = token.split(':', 2)
        memo[key.strip.to_sym] = context.evaluate(Liquid::Expression.parse(value.strip))
      end
    end
  end
end

module TranslateFilter
  def t(key, options = {})
    Datalog::I18n.translate(@context, key, options)
  end

  def localize_date(input, format = 'long')
    Datalog::I18n.localized_format(@context, input, format)
  end
end

Liquid::Template.register_tag('t', TranslateTag)
Liquid::Template.register_filter(TranslateFilter)
