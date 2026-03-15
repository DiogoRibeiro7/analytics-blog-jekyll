#!/usr/bin/env ruby
# frozen_string_literal: true

root = File.join(__dir__, "..")
layout_path = File.join(root, "_layouts", "default.html")
html = File.read(layout_path)

unless html.include?("aria-describedby=\"math-status\"")
  raise "Default layout missing math status announcement binding"
end

unless html.include?("aria-live=\"polite\"")
  raise "Math live region missing polite announcements"
end

unless html.include?("<main")
  raise "No <main> landmark found"
end

unless html =~ /<main[^>]*role\s*=\s*"main"/i
  raise "Main landmark missing role=main"
end

skip_include = File.read(File.join(root, "_includes", "skip-link.html"))

unless html.include?("include skip-link") && skip_include.include?("skip-link")
  raise "Skip link missing"
end

header = File.read(File.join(root, "_includes", "header.html"))
footer = File.read(File.join(root, "_includes", "footer.html"))
math_bundle = File.read(File.join(root, "assets", "js", "math.js"))
post_layout = File.read(File.join(root, "_layouts", "post.html"))

unless header =~ /aria-label=/i || footer =~ /aria-label=/i
  raise "Expected aria-label landmarks"
end

unless header.include?("aria-live") && header.include?("aria-hidden")
  raise "Header missing accessible progress indicators"
end

unless math_bundle.include?("aria-live")
  raise "Math toolkit missing aria-live messaging"
end

unless post_layout.include?("Copy code to clipboard")
  raise "Code copy buttons missing accessible labels"
end

puts "Accessibility landmarks verified in #{layout_path}"
