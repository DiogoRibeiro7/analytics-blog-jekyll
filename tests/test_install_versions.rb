# frozen_string_literal: true

require "minitest/autorun"
require "pathname"
require_relative "../lib/datalog/theme/version"

# The versions a reader copies from the installation docs and the starter
# template. After 0.8.0 they still said `~> 0.7` and Ruby 3.0, and the
# template's workflow built with Ruby 3.1, which cannot install 0.8.0 (#242).
# The release workflow rewrites the theme version in these files and runs this
# test before it pushes the bump.
class InstallVersionsTest < Minitest::Test
  ROOT = Pathname.new(__dir__).join("..").expand_path
  CONSUMER_FILES = [
    "README.md",
    "docs/**/*.md",
    "template/Gemfile",
    "template/**/*.md",
    "template/.github/workflows/*.yml"
  ].freeze
  GEM_CONSTRAINT = /gem "datalog-theme", "([^"]+)"/
  GIT_TAG = /gem "datalog-theme", github: "[^"]+", tag: "([^"]+)"/

  def version
    Gem::Version.new(Datalog::Theme::VERSION)
  end

  def ruby_requirement
    Gem::Requirement.new(Datalog::Theme::RUBY_REQUIREMENT)
  end

  # docs/history keeps notes written for earlier releases.
  def consumer_files
    paths = CONSUMER_FILES.flat_map { |pattern| Dir.glob(ROOT.join(pattern).to_s, File::FNM_DOTMATCH) }.uniq
    paths.reject { |path| path.include?("/docs/history/") || File.directory?(path) }
         .to_h { |path| [Pathname.new(path).relative_path_from(ROOT).to_s, File.read(path, encoding: "utf-8")] }
  end

  def matches(pattern)
    consumer_files.flat_map { |path, text| text.scan(pattern).map { |(value)| [path, value] } }
  end

  # Before 1.0 a minor release may break a site, as 0.8.0 did, so the docs pin
  # the minor series: `~> 0.8.0` takes 0.8.x and stops before 0.9.0.
  def test_gem_constraints_name_the_current_minor_series
    expected = "~> #{version.segments[0]}.#{version.segments[1]}.0"
    found = matches(GEM_CONSTRAINT)

    assert_equal %w[README.md docs/install.md template/Gemfile], found.map(&:first).uniq.sort
    found.each do |path, constraint|
      assert_equal expected, constraint, "#{path} should install the #{expected} series"
    end
  end

  def test_git_installs_pin_the_current_release_tag
    found = matches(GIT_TAG)

    refute_empty found, "docs/install.md should show a Git install pinned to a release tag"
    found.each do |path, tag|
      assert_equal "v#{version}", tag, "#{path} should pin the current release"
    end
  end

  def test_documented_ruby_versions_install_the_gem
    minimum = ruby_requirement.requirements.find { |operator, _| operator == ">=" }.last.segments.first(2).join(".")
    assert consumer_files["docs/install.md"].include?("**Ruby #{minimum} or higher**"),
           "docs/install.md should ask for Ruby #{minimum} or higher"

    workflow_rubies = matches(/ruby-version: ['"]?([\d.]+)/)
    refute_empty workflow_rubies
    workflow_rubies.each do |path, ruby|
      assert ruby_requirement.satisfied_by?(Gem::Version.new(ruby)),
             "#{path} sets up Ruby #{ruby}, which cannot install a gem that needs Ruby #{ruby_requirement}"
    end
  end

  def test_the_gemspec_uses_the_shared_ruby_requirement
    spec = Gem::Specification.load(ROOT.join("datalog-theme.gemspec").to_s)

    assert_equal ruby_requirement, spec.required_ruby_version
  end
end
