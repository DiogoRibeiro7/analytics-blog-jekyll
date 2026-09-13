source "https://rubygems.org"

gemspec

gem "loofah", "~> 2.25"

group :development do
  # gem "github-pages", "~> 232"
  gem "tzinfo-data" # provides the IANA timezone DB on Windows
  gem 'fastimage'
  gem 'nokogiri'
  gem 'wdm', '>= 0.1.0' if Gem.win_platform?
  # Pinned: the repository has no Gemfile.lock, and a newer release can enable
  # cops that fail the Lint job on code nobody changed.
  gem "rubocop", "1.85.1", require: false
end


gem "bundler-audit", "~> 0.9.2", group: :development
