#!/usr/bin/env ruby
# frozen_string_literal: true

root = File.join(__dir__, "..")
contributing = File.read(File.join(root, "CONTRIBUTING.md"))
user_guide = File.read(File.join(root, "docs", "user-guide.md"))

["Fork", "feature branch", "bundle exec rake ci:verify", "Pull Request"].each do |phrase|
  raise "Contributing guide missing required workflow phrase: #{phrase}" unless contributing.include?(phrase)
end

unless user_guide.include?("Collaboration & Version Control Workflows")
  raise "User guide missing collaboration workflows section"
end

unless user_guide.include?("Use Git LFS") && user_guide.include?("pull request")
  raise "User guide missing Git collaboration guidance"
end

puts "Collaboration workflows documented for contributors and version control guidance."
