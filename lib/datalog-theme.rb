# frozen_string_literal: true

require_relative "datalog/theme/version"

module Datalog
  module Theme
    class << self
      def root
        @root ||= File.expand_path("..", __dir__)
      end

      def assets_path
        File.join(root, "assets")
      end

      def plugins_path
        File.join(root, "_plugins")
      end

      # Jekyll loads `_plugins/` for a site but not for a theme gem, so the
      # tags and filters the layouts rely on ({% t %}, add_sri, tocify and the
      # rest) have to be required here. Sites opt in by naming the theme in
      # their `plugins:` list, which is what makes Jekyll require this file.
      def load_plugins
        Dir.glob(File.join(plugins_path, "*.rb")).sort.each do |plugin|
          require plugin
        end
      end
    end
  end
end

Datalog::Theme.load_plugins

require_relative "datalog/theme/repository_checkout"
