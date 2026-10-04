# frozen_string_literal: true

require "json"
require "open3"
require "stringio"
require "tmpdir"
require_relative "test_helper"
require_relative "../lib/datalog/cli"
require_relative "../lib/datalog/audit"

# `datalog audit` (#296): content that newer authoring features would number,
# link or describe, and problems no build reports, each with its file and
# line, read without building or writing anything.
class AuditTest < Minitest::Test
  PLANTED = <<~MARKDOWN
    ---
    title: Planted
    date: 2024-01-10
    descripton: A typo for description
    last_modified_at: 2024-06-01
    math: true
    ---
    **Definition 1.** A thing worth defining.

    > **Theorem 2 (Bayes).** A claim.

    *Proof.* Obvious.

    As Figure 3 shows, the effect is small.

    ![](/assets/img/chart.png)
    ![chart.png](/assets/img/chart.png)
    <img src="/assets/img/chart.png">

    See [the missing page](/no-such-page/).

    The code is at https://github.com/example/analysis.

    ## References

    - Smith, A. (2020). A paper.
  MARKDOWN

  CLEAN = <<~MARKDOWN
    ---
    title: A clean post
    date: 2024-01-01
    description: Nothing to report.
    tags: [example]
    ---
    A post that reads [the about page](/about/) and shows ![A bar chart of sales](/assets/img/chart.png).

    ```markdown
    **Theorem 1.** In a code block, which the audit leaves alone.
    As Figure 3 shows, ![](/x.png) and [a link](/nowhere/) and https://github.com/example/code.
    ```

    Inline `**Lemma 1.**` and `Figure 2` in code too.
  MARKDOWN

  EXPECTED = [
    ["front-matter", "_posts/2024-01-10-planted.md", 4],
    ["revisions", "_posts/2024-01-10-planted.md", 5],
    ["math", "_posts/2024-01-10-planted.md", 6],
    ["statements", "_posts/2024-01-10-planted.md", 8],
    ["statements", "_posts/2024-01-10-planted.md", 10],
    ["statements", "_posts/2024-01-10-planted.md", 12],
    ["figures", "_posts/2024-01-10-planted.md", 14],
    ["images", "_posts/2024-01-10-planted.md", 16],
    ["images", "_posts/2024-01-10-planted.md", 17],
    ["images", "_posts/2024-01-10-planted.md", 18],
    ["links", "_posts/2024-01-10-planted.md", 20],
    ["reproducibility", "_posts/2024-01-10-planted.md", 22],
    ["references", "_posts/2024-01-10-planted.md", 24],
    ["series", "_posts/2024-02-01-analysis-part-1.md", 2],
    ["series", "_posts/2024-02-08-analysis-part-2.md", 2],
    ["series", "_posts/2024-02-08-analysis-part-2.md", 7],
    ["math", "_posts/2024-03-01-math-off.md", 4]
  ].freeze

  def site(files = {})
    dir = Dir.mktmpdir("datalog-audit")
    TestSite.directories << dir
    {
      "_config.yml" => "title: Audit fixture\nurl: https://example.org\n",
      "about.md" => "---\ntitle: About\n---\nAbout this site.\n",
      "assets/img/chart.png" => "not really a png",
      "_posts/2024-01-01-clean.md" => CLEAN
    }.merge(files).each do |path, contents|
      FileUtils.mkdir_p(File.dirname(File.join(dir, path)))
      File.write(File.join(dir, path), contents)
    end
    dir
  end

  def planted_site
    site(
      "_posts/2024-01-10-planted.md" => PLANTED,
      "_posts/2024-02-01-analysis-part-1.md" => "---\ntitle: Analysis, Part 1\ndate: 2024-02-01\n---\nFirst.\n",
      "_posts/2024-02-08-analysis-part-2.md" => "---\ntitle: Analysis, Part 2\ndate: 2024-02-08\n---\nSecond.\n\n" \
                                                "Back to [Part 1](/2024/02/01/analysis-part-1.html).\n",
      "_posts/2024-03-01-math-off.md" => "---\ntitle: Math off\ndate: 2024-03-01\nmath: false\n---\n" \
                                         "The area is $\\pi r^2$.\n"
    )
  end

  def audit(root, **)
    Datalog::Audit.new(root: root, **).run
  end

  def found(report)
    report.findings.map { |finding| [finding.check, finding.file, finding.line] }
  end

  # The CLI's output and exit status, with its standard output captured.
  def cli(*args)
    out = StringIO.new
    status = 0
    original = $stdout
    $stdout = out
    begin
      Datalog::CLI.start(["audit", *args])
    rescue SystemExit => e
      status = e.status
    ensure
      $stdout = original
    end
    [out.string, status]
  end

  def test_every_planted_pattern_is_found_with_its_file_and_line
    assert_equal EXPECTED.sort, found(audit(planted_site)).sort
  end

  def test_a_clean_post_reports_nothing
    report = audit(site)

    assert_empty report.findings.map(&:to_h)
  end

  def test_the_kinds_split_into_problems_and_opportunities
    report = audit(planted_site)

    assert_equal %w[front-matter images links math], report.problems.map(&:check).uniq.sort
    assert_equal %w[figures references reproducibility revisions series statements],
                 report.opportunities.map(&:check).uniq.sort
  end

  def test_unknown_keys_come_from_the_theme_sources_and_the_site_settings
    keys = Datalog::Audit::KnownKeys.build(theme_root: Datalog::Audit::THEME_ROOT, site_root: site)

    %w[why_this_exists reproducibility series revisions bibliography nocite provenance_position].each do |key|
      assert_includes keys, key, "the theme reads #{key}"
    end
    refute_includes keys, "descripton"
    assert_empty found(audit(site("_config.yml" => "title: T\naudit:\n  known_keys: [descripton]\n",
                                  "_posts/2024-05-01-typo.md" => "---\ntitle: T\ndescripton: x\n---\nText.\n")))
  end

  # A showcase page passes its own front matter to an include; a listing reads
  # a field of each post. Either is a reader, even outside the templates.
  def test_a_key_read_by_liquid_in_the_content_is_known
    root = site(
      "showcase.md" => "---\ntitle: Showcase\nshowcase_data: {title: x}\n---\n{{ page.showcase_data.title }}\n",
      "_posts/2024-05-01-listed.md" => "---\ntitle: Listed\nteaser_line: Read me\n---\nText.\n",
      "index.md" => "---\ntitle: Home\n---\n{% for post in site.posts %}{{ post.teaser_line }}{% endfor %}\n"
    )

    assert_empty found(audit(root, only: "front-matter"))
  end

  # A repository is judged by an address's host, not by its name anywhere in
  # the address; and lines of brackets or braces, which took quadratic time
  # in the patterns these replaced, are read in linear time.
  def test_links_are_judged_by_host_and_long_lines_stay_fast
    reader = Struct.new(:config, :git_dates) { def built?(_) = true }.new({}, {})
    checks = Datalog::Audit::Checks.new(reader: reader, known_keys: Set.new, settings: {})
    source = lambda do |body|
      dir = Dir.mktmpdir("datalog-audit-lines").tap { |made| TestSite.directories << made }
      path = File.join(dir, "_posts", "2024-01-01-x.md")
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, "---\ntitle: X\n---\n#{body}\n")
      Datalog::Audit::SourceFile.new(path, "_posts/2024-01-01-x.md")
    end

    assert_empty checks.reproducibility(source.call("See https://example.com/?next=https://github.com/a/b."))
    refute_empty checks.reproducibility(source.call("See https://www.github.com/a/b."))

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    long = source.call("#{'[' * 40_000}\n#{'![' * 40_000}\n#{'[a](' * 20_000}")
    %i[images links series].each { |check| checks.public_send(check, long) }
    Datalog::Audit::KnownKeys.from_content("{{" * 40_000)

    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 3
  end

  def test_the_demo_has_no_unknown_front_matter_keys
    report = audit(TestSite.root, only: "front-matter")

    assert_empty(report.findings.map { |finding| "#{finding.file}:#{finding.line} #{finding.message}" })
    assert_operator report.files.size, :>, 40
  end

  def test_strict_exits_one_on_a_problem_and_zero_on_opportunities_alone
    _, with_problems = cli("--root", planted_site, "--strict")
    _, opportunities = cli("--root", site("_posts/2024-06-01-typed.md" => "---\ntitle: T\n---\n**Lemma 1.** Typed.\n"),
                           "--strict")
    _, without_strict = cli("--root", planted_site)

    assert_equal 1, with_problems
    assert_equal 0, opportunities
    assert_equal 0, without_strict
  end

  def test_the_audit_never_writes_to_the_site
    root = planted_site
    snapshot = lambda do
      Dir.glob("**/*", File::FNM_DOTMATCH, base: root).reject { |path| path.end_with?(".") }
         .to_h { |path| [path, File.file?(File.join(root, path)) ? File.mtime(File.join(root, path)) : :dir] }
    end
    before = snapshot.call
    %w[text json markdown].each { |format| cli("--root", root, "--format", format) }

    assert_equal before, snapshot.call
  end

  def test_json_and_markdown_carry_every_finding
    root = planted_site
    json, = cli("--root", root, "--format", "json")
    markdown, = cli("--root", root, "--format", "markdown")
    data = JSON.parse(json)

    assert_equal({ "problems" => 7, "opportunities" => 10 }, data["summary"])
    assert_equal({ "kind" => "problem", "check" => "front-matter", "file" => "_posts/2024-01-10-planted.md",
                   "line" => 4 }, data["problems"].first.except("message"))
    assert_includes markdown, "### Problems"
    assert_includes markdown, "- `_posts/2024-01-10-planted.md:20` links /no-such-page/"
  end

  def test_only_and_path_narrow_the_audit
    root = planted_site

    assert_equal %w[series], audit(root, only: "series").findings.map(&:check).uniq
    assert_equal ["_posts/2024-03-01-math-off.md"],
                 audit(root, path: "_posts/2024-03-01-math-off.md").findings.map(&:file).uniq
    output, status = cli("--root", root, "--only", "statements,nonsense")
    assert_equal 2, status
    assert_includes output, "unknown check nonsense"
  end

  def test_git_history_counts_an_edit_but_not_a_sweeping_commit
    root = site("_posts/2024-01-01-clean.md" => "---\ntitle: Edited\ndate: 2024-01-01\n---\nFirst.\n")
    commit = lambda do |date, message|
      env = { "GIT_AUTHOR_DATE" => date, "GIT_COMMITTER_DATE" => date }
      Open3.capture2e(env, "git", "-C", root, "-c", "user.name=T", "-c", "user.email=t@example.org",
                      "commit", "-qam", message)
    end
    Open3.capture2e("git", "-C", root, "init", "-q")
    Open3.capture2e("git", "-C", root, "add", ".")
    commit.call("2024-01-01T10:00:00Z", "Publish")
    12.times { |index| File.write(File.join(root, "note-#{index}.md"), "---\ntitle: N\n---\nx\n") }
    Open3.capture2e("git", "-C", root, "add", ".")
    File.write(File.join(root, "_posts/2024-01-01-clean.md"), "---\ntitle: Edited\ndate: 2024-01-01\n---\nSwept.\n")
    commit.call("2024-03-01T10:00:00Z", "Reformat everything")

    assert_empty audit(root, only: "revisions").findings, "a commit of 14 files is not an edit"

    File.write(File.join(root, "_posts/2024-01-01-clean.md"), "---\ntitle: Edited\ndate: 2024-01-01\n---\nFixed.\n")
    commit.call("2024-06-01T10:00:00Z", "Correct the estimate")
    finding = audit(root, only: "revisions").findings.first

    assert_equal ["_posts/2024-01-01-clean.md", 1], [finding.file, finding.line]
    assert_includes finding.message, "152 days after publication (its last commit)"
  end
end
