#!/usr/bin/env ruby
# frozen_string_literal: true

root = File.join(__dir__, "..")
layout_path = File.join(root, "_layouts", "default.html")
html = File.read(layout_path)

raise "Default layout missing math status announcement binding" unless html.include?("aria-describedby=\"math-status\"")

raise "Math live region missing polite announcements" unless html.include?("aria-live=\"polite\"")

raise "No <main> landmark found" unless html.include?("<main")

raise "Main landmark missing role=main" unless html =~ /<main[^>]*role\s*=\s*"main"/i

skip_include = File.read(File.join(root, "_includes", "skip-link.html"))

raise "Skip link missing" unless html.include?("include skip-link") && skip_include.include?("skip-link")

header = File.read(File.join(root, "_includes", "header.html"))
footer = File.read(File.join(root, "_includes", "footer.html"))
math_bundle = File.read(File.join(root, "assets", "js", "math.js"))
post_layout = File.read(File.join(root, "_layouts", "post.html"))

raise "Expected aria-label landmarks" unless header =~ /aria-label=/i || footer =~ /aria-label=/i

unless header.include?("aria-live") && header.include?("aria-hidden")
  raise "Header missing accessible progress indicators"
end

raise "Math toolkit missing aria-live messaging" unless math_bundle.include?("aria-live")

raise "Code copy buttons missing accessible labels" unless post_layout.include?("Copy code to clipboard")

puts "Accessibility landmarks verified in #{layout_path}"
