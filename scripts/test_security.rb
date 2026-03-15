#!/usr/bin/env ruby
# frozen_string_literal: true

root = File.join(__dir__, "..")
head = File.read(File.join(root, "_includes", "head.html"))
visualizations = File.read(File.join(root, "assets", "js", "visualizations.js"))
post_layout = File.read(File.join(root, "_layouts", "post.html"))
research_layout = File.read(File.join(root, "_layouts", "research.html"))

unless head.include?("Content-Security-Policy")
  raise "Head include missing CSP declaration"
end

%w[sandbox allow-scripts allow-same-origin].each do |token|
  unless visualizations.include?(token)
    raise "Visualization embeds missing #{token} enforcement"
  end
end

unless post_layout.include?("rel=\"noopener noreferrer\"") && research_layout.include?("rel=\"noopener noreferrer\"")
  raise "External links must use rel=\"noopener noreferrer\" for security"
end

puts "Security hardening verified for CSP, sandboxed visualizations, and safe external links."
