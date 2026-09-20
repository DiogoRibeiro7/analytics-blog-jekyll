# frozen_string_literal: true

module Datalog
  module Theme
    VERSION = "0.9.2" unless const_defined?(:VERSION)
    # The Ruby the gem installs on, for the gemspec and `datalog check`. The
    # release workflow rewrites every quoted version assigned to a name ending
    # in VERSION in this file, so this name must not end that way.
    RUBY_REQUIREMENT = ">= 3.2" unless const_defined?(:RUBY_REQUIREMENT)
  end
end
