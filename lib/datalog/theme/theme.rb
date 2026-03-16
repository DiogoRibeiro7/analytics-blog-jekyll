# frozen_string_literal: true

require "jekyll"
require_relative "theme/version"

module Datalog
  module Theme
    class << self
      def register
        Jekyll::Hooks.register :site, :after_init do |_site|
          Jekyll.logger.info "Datalog Theme:", "Loaded version #{VERSION}"
        end
      end
    end
  end
end

Datalog::Theme.register
