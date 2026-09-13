# frozen_string_literal: true

require "minitest/autorun"
require "yaml"

# Guards in the release and CI workflows that are easy to lose in an edit.
class WorkflowsTest < Minitest::Test
  WORKFLOWS = File.expand_path("../.github/workflows", __dir__)

  def workflow(name)
    YAML.safe_load_file(File.join(WORKFLOWS, name), aliases: true)
  end

  def step_names(job)
    job.fetch("steps").map { |step| step["name"] }
  end

  # A manual run from a branch published whatever that branch held, and nothing
  # compared the tag with the version being published.
  def test_gem_release_publishes_only_a_tag_that_matches_the_version
    job = workflow("gem-release.yml").dig("jobs", "release")
    assert_equal "startsWith(github.ref, 'refs/tags/v')", job["if"]

    names = step_names(job)
    check = names.index("Check the tag matches the gem version")
    refute_nil check, "gem-release.yml should compare the tag with version.rb"
    assert_operator(check, :<, names.index { |name| name.start_with?("Publish gem") })
  end

  # The package used to be checked only after the tag and the GitHub release existed.
  def test_release_verifies_the_gem_before_tagging
    names = step_names(workflow("release.yml").dig("jobs", "tag"))
    verify = names.index("Build and verify the gem before tagging")
    refute_nil verify, "release.yml should build and verify the gem in the tag job"
    assert_operator verify, :<, names.index("Tag and create the GitHub release")
  end

  def test_linters_run_and_gate_the_test_summary
    jobs = workflow("test.yml")["jobs"]
    assert_includes step_names(jobs["lint"]), "Run ESLint"
    assert_includes step_names(jobs["lint"]), "Run RuboCop"
    assert_includes jobs.dig("test-summary", "needs"), "lint"
  end

  def test_python_audit_can_fail
    steps = workflow("dependency-review.yml").dig("jobs", "python-audit", "steps")
    steps.each { |step| refute step["continue-on-error"], "#{step['name']} should not ignore failures" }
    assert(steps.any? { |step| step["run"].to_s.include?("pip-audit -r requirements.txt") })
  end
end
