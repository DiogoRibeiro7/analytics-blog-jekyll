# frozen_string_literal: true

module Datalog
  module Theme
    VERSION = "0.8.0" unless const_defined?(:VERSION)
    # The Ruby the gem installs on, for the gemspec and `datalog check`. Its name
    # keeps it out of the release workflow's `VERSION = "..."` substitution.
    RUBY_REQUIREMENT = ">= 3.2" unless const_defined?(:RUBY_REQUIREMENT)
  end
end
