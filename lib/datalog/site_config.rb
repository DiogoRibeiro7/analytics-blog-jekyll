# frozen_string_literal: true

require "date"
require "yaml"

module Datalog
  # A site's _config.yml as the CLI's commands read it, which has to be as
  # Jekyll reads it: a date, a time or a YAML alias that builds fine must not
  # stop `datalog update`, `check` or `critical-css`. Each command used to call
  # the safe loader itself, and the updater's permitted no dates, so a site
  # with `launched: 2024-01-01` in its configuration failed the update after
  # the theme checkout had already moved.
  module SiteConfig
    PERMITTED_CLASSES = [Date, Time].freeze

    module_function

    # The settings in a configuration file, or {} when there is none.
    # A file that is not valid YAML still raises Psych::SyntaxError.
    def load(path)
      return {} unless File.file?(path)

      YAML.safe_load_file(path, permitted_classes: PERMITTED_CLASSES, aliases: true) || {}
    end
  end
end
