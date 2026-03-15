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
    end
  end
end
