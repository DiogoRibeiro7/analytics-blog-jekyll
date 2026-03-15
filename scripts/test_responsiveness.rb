#!/usr/bin/env ruby
# frozen_string_literal: true

root = File.join(__dir__, "..")
base_styles = File.read(File.join(root, "_sass", "_base.scss"))
mixins = File.read(File.join(root, "_sass", "_mixins.scss"))
components = File.read(File.join(root, "_sass", "_components.scss"))

unless base_styles.include?("pre {\n  overflow-x: auto;")
  raise "Code blocks must allow horizontal scrolling on small screens"
end

unless mixins.include?("@mixin math-display") && mixins.include?("max-width: 100%") && mixins.include?("overflow-x: auto")
  raise "Math display mixin missing responsive overflow handling"
end

unless components.include?(".equation-block") && components.include?("justify-items: center")
  raise "Equation block styles missing responsive centering"
end

unless components.include?("@include code-block()") && components.include?("code-block__copy")
  raise "Code block components missing responsive wrappers"
end

puts "Responsive styling verified for code and math content."
