# frozen_string_literal: true

require_relative "test_helper"
require_relative "support/test_site"
require "date"
require "json"
require "nokogiri"
require "tmpdir"
require "yaml"
require_relative "../lib/datalog/packages"
require_relative "../lib/datalog/packages/refresh"
require_relative "../lib/datalog/packages/command"
require_relative "../lib/datalog/cli"

# Package pages that know their registries (#290). The layout and the install
# panel assumed a Python or an R package with its metadata typed by hand: a
# crate or a gem had nowhere to go, and a version in front matter went stale
# with the next release. Each registry a page names in `registry:` now gives
# its link and its install tab, `datalog packages refresh` reads the releases
# into a data file the layout prefers, an include lists every package, and the
# page describes the package as SoftwareSourceCode.
class PackageRegistriesTest < Minitest::Test
  def test_a_crate_links_to_crates_io_and_docs_rs_and_installs_with_cargo_add
    data = { "registry" => { "crates" => "copula-core" } }

    assert_equal([%w[crates crates.io https://crates.io/crates/copula-core],
                  %w[docs_rs docs.rs https://docs.rs/copula-core]],
                 Datalog::Packages.links(data).map { |link| link.values_at("registry", "label", "url") })
    tabs = Datalog::Packages.install_tabs(data, language: "Rust")
    assert_equal [["cargo", "cargo", [["terminal", "cargo add copula-core"]]]], summary(tabs)
  end

  def test_a_gem_installs_with_gem_install_and_a_gemfile_line
    tabs = Datalog::Packages.install_tabs({ "registry" => { "rubygems" => "datalog-inspect" } }, language: "Ruby")

    assert_equal [["gem", "gem", [["terminal", "gem install datalog-inspect"], ["gemfile", 'gem "datalog-inspect"']]]],
                 summary(tabs)
  end

  def test_every_registry_gives_a_link_and_a_tab
    names = Datalog::Packages::REGISTRIES.keys.to_h { |key| [key, "pkg"] }
    tabs = Datalog::Packages.install_tabs({ "registry" => names })

    assert_equal(%w[pip conda cran cargo gem npm julia], tabs.map { |tab| tab["id"] })
    assert_equal(["npm install pkg", 'using Pkg; Pkg.add("pkg")'], tabs.last(2).map do |tab|
      tab["commands"][0]["command"]
    end)
    assert_equal(%w[pypi conda_forge cran crates docs_rs rubygems npm julia],
                 Datalog::Packages.links({ "registry" => names }).map { |link| link["registry"] })
  end

  # Pages written before `registry:` keep their links and tabs.
  def test_pypi_url_and_cran_url_still_name_their_registries
    data = { "pypi_url" => "https://pypi.org/project/statflow/", "cran_url" => "https://cran.r-project.org/package=tidyx" }

    assert_equal({ "pypi" => "statflow", "cran" => "tidyx" }, Datalog::Packages.registries(data))
    assert_equal(["https://pypi.org/project/statflow/", "https://cran.r-project.org/package=tidyx"],
                 Datalog::Packages.links(data).map { |link| link["url"] })
  end

  # A Python or R page that names no registry keeps the tabs it always had.
  def test_a_page_without_registries_keeps_its_languages_tabs
    python = Datalog::Packages.install_tabs({}, language: "python", name: "statflow",
                                                git_url: "https://github.com/example/statflow")
    r = Datalog::Packages.install_tabs({}, language: "r", name: "tidyx", git_url: "https://github.com/example/tidyx")

    assert_equal [["pip", "pip", [["terminal", "pip install statflow"]]],
                  ["conda", "conda", [["terminal", "conda install statflow"]]],
                  ["git", "Git", [["terminal", "git clone https://github.com/example/statflow\ncd statflow\npip install -e ."]]]],
                 summary(python)
    assert_equal [["cran", "CRAN", [["r_console", "install.packages('tidyx')"]]],
                  ["github", "GitHub", [["r_console", 'devtools::install_github("example/tidyx")']]]], summary(r)
  end

  def test_an_unsupported_language_gets_the_git_tab_alone_and_no_repository_gets_nothing
    tabs = Datalog::Packages.install_tabs({}, language: "Haskell", name: "lenses",
                                              git_url: "https://github.com/example/lenses-hs.git")

    assert_equal [["git", "Git", [["terminal", "git clone https://github.com/example/lenses-hs.git\ncd lenses-hs"]]]],
                 summary(tabs)
    assert_empty Datalog::Packages.install_tabs({}, language: "Haskell", name: "lenses")
  end

  def test_pre_releases_are_told_from_releases
    %w[1.0a1 2.0b3 2.0rc1 1.0.dev3 1.0.0-beta.2 3.0.0-rc.1 2.0.0.pre1].each do |version|
      assert Datalog::Packages.prerelease?(version), "#{version} is a pre-release"
    end
    %w[1.0 1.2.3 1.0.post1 1.0.0+build.5 2024.10].each do |version|
      refute Datalog::Packages.prerelease?(version), "#{version} is a release"
    end
  end

  private

  def summary(tabs)
    tabs.map do |tab|
      [tab["id"], tab["label"], tab["commands"].map do |command|
        command.values_at("console", "command")
      end]
    end
  end
end

# `datalog packages refresh`, against fixtures standing in for each registry.
class PackageRefreshTest < Minitest::Test
  Refresh = Datalog::Packages::Refresh

  # Each registry's answer for one package, as its API sends it, cut down.
  PYPI = {
    "info" => { "name" => "heavytails", "version" => "0.4.1", "license_expression" => "MIT", "license" => "",
                "requires_python" => ">=3.10" },
    "releases" => {
      "0.4.0" => [{ "upload_time_iso_8601" => "2026-05-01T08:00:00.000000Z", "yanked" => false }],
      "0.4.1" => [{ "upload_time_iso_8601" => "2026-08-14T09:13:00.000000Z", "yanked" => false },
                  { "upload_time_iso_8601" => "2026-08-14T09:12:03.123456Z", "yanked" => false }]
    }
  }.freeze
  CRATES = {
    "crate" => { "name" => "copula-core", "max_version" => "0.4.0-beta.1", "max_stable_version" => "0.3.0",
                 "newest_version" => "0.4.0-beta.1" },
    "versions" => [
      { "num" => "0.4.0-beta.1", "created_at" => "2026-09-20T10:00:00.000000+00:00", "license" => "MIT OR Apache-2.0" },
      { "num" => "0.3.0", "created_at" => "2026-07-01T10:00:00.000000+00:00", "license" => "MIT OR Apache-2.0",
        "rust_version" => "1.74", "yanked" => false }
    ]
  }.freeze
  RUBYGEMS = [
    { "number" => "2.0.0.pre1", "prerelease" => true, "created_at" => "2026-09-01T12:00:00.000Z",
      "licenses" => ["MIT"] },
    { "number" => "1.4.0", "prerelease" => false, "created_at" => "2026-05-02T12:00:00.000Z",
      "licenses" => ["MIT"], "ruby_version" => ">= 3.1" }
  ].freeze
  ANSWERS = {
    "https://pypi.org/pypi/heavytails/json" => PYPI,
    "https://crates.io/api/v1/crates/copula-core" => CRATES,
    "https://rubygems.org/api/v1/versions/datalog-inspect.json" => RUBYGEMS
  }.transform_values { |json| [200, JSON.generate(json)] }.freeze

  def test_refresh_writes_the_release_of_a_pypi_a_crates_io_and_a_rubygems_package
    with_package_site do |dir|
      data, = Refresh.new(root: dir, fetch: ->(url) { ANSWERS.fetch(url) }).run
      written = YAML.safe_load_file(File.join(dir, "_data", "package_releases.yml"))

      assert_equal data, written
      assert_equal %w[crates pypi rubygems], written.keys, "conda-forge has no API to read, so it is not asked"
      assert_equal({ "version" => "0.4.1", "released" => "2026-08-14", "license" => "MIT", "prerelease" => false,
                     "requires_python" => ">=3.10" }, written.dig("pypi", "heavytails"))
      assert_equal({ "version" => "0.3.0", "released" => "2026-07-01", "license" => "MIT OR Apache-2.0",
                     "prerelease" => false, "rust_version" => "1.74" },
                   written.dig("crates", "copula-core"), "the latest stable release, not the beta")
      assert_equal({ "version" => "1.4.0", "released" => "2026-05-02", "license" => "MIT", "prerelease" => false,
                     "required_ruby_version" => ">= 3.1" },
                   written.dig("rubygems", "datalog-inspect"))
      file = File.read(File.join(dir, "_data", "package_releases.yml"))
      assert file.start_with?(Refresh::HEADER)
      Refresh.new(root: dir, fetch: ->(url) { ANSWERS.fetch(url) }).run
      assert_equal file, File.read(File.join(dir, "_data", "package_releases.yml")),
                   "with no new release, a second run changes nothing, so a scheduled one proposes nothing"
    end
  end

  def test_refresh_leaves_the_file_alone_when_a_registry_cannot_be_reached
    with_package_site do |dir|
      file = File.join(dir, "_data", "package_releases.yml")
      File.write(file, "pypi:\n  heavytails:\n    version: 0.1.0\n")
      fetch = lambda do |url|
        raise SocketError, "getaddrinfo: Name or service not known" if url.include?("crates.io")

        ANSWERS.fetch(url)
      end

      error = assert_raises(Refresh::Error) { Refresh.new(root: dir, fetch: fetch).run }
      assert_includes error.message, "No release was written"
      assert_includes error.message, "_packages/copula-core.md: could not reach crates.io at " \
                                     "https://crates.io/api/v1/crates/copula-core"
      assert_equal "pypi:\n  heavytails:\n    version: 0.1.0\n", File.read(file)
    end
  end

  def test_refresh_names_a_package_the_registry_lacks_and_an_answer_that_is_no_release
    with_package_site do |dir|
      fetch = lambda do |url|
        next [404, "Not Found"] if url.include?("rubygems")
        next [200, "<!doctype html><title>Maintenance</title>"] if url.include?("pypi")

        ANSWERS.fetch(url)
      end

      error = assert_raises(Refresh::Error) { Refresh.new(root: dir, fetch: fetch).run }
      assert_includes error.message, "RubyGems has no package named datalog-inspect"
      assert_includes error.message, "PyPI sent an answer for heavytails that is not a release"
      refute File.exist?(File.join(dir, "_data", "package_releases.yml"))
    end
  end

  def test_refresh_marks_a_yanked_release_and_a_pre_release
    yanked = PYPI.merge("releases" => { "0.4.1" => [{ "upload_time_iso_8601" => "2026-08-14T09:12:03Z",
                                                      "yanked" => true }] })
    npm = { "dist-tags" => { "latest" => "3.0.0-rc.1" }, "time" => { "3.0.0-rc.1" => "2026-09-09T00:00:00.000Z" },
            "versions" => { "3.0.0-rc.1" => { "license" => "ISC", "engines" => { "node" => ">=20" } } } }

    assert_equal true, Datalog::Packages::Releases.pypi(yanked)["yanked"]
    assert_equal({ "version" => "3.0.0-rc.1", "released" => "2026-09-09", "license" => "ISC", "prerelease" => true,
                   "node_version" => ">=20" }, Datalog::Packages::Releases.npm(npm))
  end

  def test_refresh_asks_with_a_user_agent
    request = nil
    http = Object.new
    http.define_singleton_method(:request) do |sent|
      request = sent
      Struct.new(:code, :body).new("200", "{}")
    end
    original = Net::HTTP.method(:start)
    Net::HTTP.define_singleton_method(:start) { |*_args, **_options, &block| block.call(http) }
    begin
      Refresh.new(root: Dir.pwd).http_get("https://crates.io/api/v1/crates/copula-core")
    ensure
      Net::HTTP.define_singleton_method(:start, original)
    end

    assert_match %r{\Adatalog-theme/\S+ \(\+https://github\.com/}, request["User-Agent"],
                 "crates.io refuses a request without one"
  end

  def test_the_command_reports_what_it_wrote_and_exits_1_when_a_registry_fails
    with_package_site do |dir|
      ok = Datalog::PackagesCommand.new([], { root: dir })
      ok.define_singleton_method(:new_refresher) { Refresh.new(root: dir, fetch: ->(url) { ANSWERS.fetch(url) }) }
      out, = capture_io { ok.refresh }
      assert_includes out, "Wrote 3 releases to _data/package_releases.yml"

      failing = Datalog::PackagesCommand.new([], { root: dir })
      failing.define_singleton_method(:new_refresher) { Refresh.new(root: dir, fetch: ->(_url) { raise "offline" }) }
      error = assert_raises(SystemExit) { capture_io { failing.refresh } }
      assert_equal 1, error.status
    end
  end

  def test_the_cli_has_the_packages_command
    assert_equal Datalog::PackagesCommand, Datalog::CLI.subcommand_classes["packages"]
  end

  private

  # A site with a PyPI and conda-forge package, a crate and a gem, for refresh.
  def with_package_site
    Dir.mktmpdir("datalog-packages") do |dir|
      File.write(File.join(dir, "_config.yml"), "title: Packages\n")
      {
        "heavytails" => { "registry" => { "pypi" => "heavytails", "conda_forge" => "heavytails" } },
        "copula-core" => { "registry" => { "crates" => "copula-core" } },
        "datalog-inspect" => { "registry" => { "rubygems" => "datalog-inspect" } },
        "notes" => { "language" => "Haskell" }
      }.each do |name, front|
        FileUtils.mkdir_p(File.join(dir, "_packages"))
        File.write(File.join(dir, "_packages", "#{name}.md"), "#{front.merge('title' => name).to_yaml}---\nBody.\n")
      end
      FileUtils.mkdir_p(File.join(dir, "_data"))
      yield dir
    end
  end
end

# The package layout, the install panel, the index and the JSON-LD, built.
class PackagePagesTest < Minitest::Test
  # The properties schema.org gives SoftwareSourceCode, through CreativeWork
  # and Thing, of those a package page can have.
  SOFTWARE_SOURCE_CODE = %w[
    @context @type @id name url description mainEntityOfPage sameAs codeRepository programmingLanguage
    runtimePlatform version license author
  ].freeze

  def test_a_crate_page_renders_crates_io_docs_rs_and_a_cargo_add_tab
    page = built.document("packages/copula-core/index.html")

    assert_equal({ "crates" => "https://crates.io/crates/copula-core", "docs_rs" => "https://docs.rs/copula-core" },
                 page.css(".package-docs__actions [data-registry]").to_h do |link|
                   [link["data-registry"], link["href"]]
                 end)
    assert_equal(%w[cargo git], page.css("[role=tab]").map { |tab| tab["data-tab"] })
    assert_equal ["cargo add copula-core", "git clone https://github.com/example/copula-rs\ncd copula-rs"],
                 page.css(".package-install code").map(&:text)
    assert_includes page.at_css(".package-docs__language").text, "Rust >= 1.74"
  end

  def test_a_gem_page_renders_gem_install_and_the_gemfile_line
    page = built.document("packages/datalog-inspect/index.html")
    panel = page.at_css("[data-tab-content=gem]")

    assert_equal ["gem install datalog-inspect", 'gem "datalog-inspect"'], panel.css("code").map(&:text)
    assert_equal(%w[Terminal Gemfile], panel.css(".package-install__code-label").map { |label| label.text.strip })
    ids = page.css("[id]").map { |node| node["id"] }
    assert_equal ids.uniq, ids, "each command has its own id for its copy button"
    assert_equal(panel.css("code").map { |code| code["id"] },
                 panel.css("[data-copy-target]").map { |button| button["data-target"] })
  end

  def test_the_data_files_release_wins_over_an_older_front_matter_version
    page = built.document("packages/heavytails/index.html")
    version = page.at_css("[data-package-version]")

    assert_includes version.text, "v0.4.1"
    refute_includes page.at_css(".package-docs__header").text, "0.2.0"
    assert_equal "2026-08-14", version.at_css("time")["datetime"]
    assert_includes page.at_css(".package-docs__language").text, "Python >=3.10"
    assert_equal "https://heavytails.example.org/", page.at_css("[data-registry=docs]")["href"]
  end

  def test_a_pre_release_says_so
    assert_includes built.document("packages/datalog-inspect/index.html").at_css("[data-package-version]").text,
                    "v2.0.0.rc1 · pre-release"
  end

  def test_without_a_release_in_the_data_file_the_front_matter_is_shown
    page = built.document("packages/legacy-stats/index.html")

    assert_includes page.at_css("[data-package-version]").text, "v1.0.0"
    assert_equal "https://pypi.org/project/legacy-stats/", page.at_css("[data-registry=pypi]")["href"]
    assert_equal "pip install legacy-stats[all]", page.at_css("[data-tab-content=pip] code").text,
                 "the include's pip_command still replaces the command"
    assert_includes page.at_css(".package-docs__meta").text, "Beta"
  end

  def test_an_unsupported_language_renders_the_git_tab_alone_and_nothing_renders_no_panel
    assert_equal(%w[git], built.document("packages/notes/index.html").css("[role=tab]").map { |tab| tab["data-tab"] })

    bare = built.document("packages/bare/index.html")
    assert_nil bare.at_css(".package-install"), "no registry and no repository: no Installation heading over nothing"
  end

  def test_the_index_lists_every_package_with_its_release_and_install_command
    cards = built.html("index.html").css("[data-package-index] article")

    assert_equal(["Bare", "Copula Core", "Datalog Inspect", "HeavyTails", "Legacy Stats", "Notes"],
                 cards.map { |card| card.at_css("h2").text.strip })
    heavytails = cards.find { |card| card["data-package"] == "heavytails" }
    assert_equal "v0.4.1", heavytails.at_css("[data-package-version]").text
    assert_equal "pip install heavytails", heavytails.at_css("code").text
    assert_equal(["/packages/heavytails/", "https://github.com/example/heavytails", "https://pypi.org/project/heavytails/"],
                 heavytails.css(".project-links a").map { |link| link["href"] })
    assert_nil cards.find { |card| card["data-package"] == "notes" }.at_css("code"),
               "a clone is not an install command"
  end

  def test_the_index_as_a_table_grouped_by_language
    index = built.html("table/index.html").at_css("[data-package-index]")

    assert_equal %w[Haskell Python Ruby Rust Other], index.css("h2").map(&:text)
    assert_equal(%w[Haskell Python Ruby Rust Other], index.css(".content-table").map { |region| region["aria-label"] })
    python = index.css("table")[1]
    assert_equal %w[Package Release Install Purpose], python.css("thead th").map(&:text)
    assert_equal([["HeavyTails", "v0.4.1", "pip install heavytails", "Heavy-tailed distributions"],
                  ["Legacy Stats", "v1.0.0", "pip install legacy-stats", "An older package"]],
                 python.css("tbody tr").map do |row|
                   [row.at_css("th").text, row.at_css("[data-package-version]")&.text,
                    row.at_css("code")&.text, row.css("td").last.text]
                 end)
    assert_empty index.css(".content-table .content-table"), "the region the include writes is not wrapped twice"
  end

  def test_the_index_says_when_there_are_no_packages
    site = TestSite.build(collections: { "packages" => { "output" => true } }) do |source|
      source.theme("_includes/components/package-index.html", "_data/i18n")
      source.page("index.html", "{% include components/package-index.html %}")
    end

    assert_equal "No packages yet.", site.html("index.html").at_css(".package-index__empty").text
  end

  def test_a_package_page_describes_the_package_as_software_source_code
    code = software_source_code(built.read("packages/heavytails/index.html"))

    assert_empty code.keys - SOFTWARE_SOURCE_CODE, "every property is one schema.org gives SoftwareSourceCode"
    assert_equal "SoftwareSourceCode", code["@type"]
    assert_equal "HeavyTails", code["name"]
    assert_equal "https://example.org/packages/heavytails/", code["url"]
    assert_equal "https://github.com/example/heavytails", code["codeRepository"]
    assert_equal "Python", code["programmingLanguage"]
    assert_equal "0.4.1", code["version"]
    assert_equal "Python >=3.10", code["runtimePlatform"]
    assert_equal "https://spdx.org/licenses/MIT.html", code["license"]
    assert_equal "Test", code.dig("author", "name")
    assert_equal ["https://pypi.org/project/heavytails/", "https://anaconda.org/conda-forge/heavytails",
                  "https://heavytails.example.org/"], code["sameAs"]

    crate = software_source_code(built.read("packages/copula-core/index.html"))
    assert_equal "MIT OR Apache-2.0", crate["license"], "the registry's licence, when front matter has none"
    assert_equal ["https://crates.io/crates/copula-core", "https://docs.rs/copula-core"], crate["sameAs"]
  end

  def test_only_package_pages_describe_a_package
    assert_nil software_source_code(built.read("table/index.html"))
  end

  # The demo's /packages/ is the include, not a loop of its own.
  def test_the_demo_packages_page_uses_the_index
    index = Nokogiri::HTML5(SiteBuilder.read("packages/index.html")).at_css("[data-package-index]")

    refute_nil index
    assert_equal(["statflow"], index.css("[data-package]").map { |card| card["data-package"] })
    statflow = software_source_code(SiteBuilder.read("packages/statflow/index.html"))
    assert_equal "1.2.3", statflow["version"]
  end

  private

  def software_source_code(html)
    Nokogiri::HTML5(html).css('script[type="application/ld+json"]')
            .map { |node| JSON.parse(node.text) }
            .find { |block| block["@type"] == "SoftwareSourceCode" }
  end

  def built
    self.class.built ||= build_site
  end

  class << self
    attr_accessor :built
  end

  def build_site
    TestSite.build(
      collections: { "packages" => { "output" => true, "permalink" => "/packages/:name/" } },
      defaults: [{ "scope" => { "path" => "", "type" => "packages" }, "values" => { "layout" => "package" } }]
    ) do |source|
      source.theme("_layouts", "_includes", "_data")
      source.data("package_releases.yml", {
                    "pypi" => { "heavytails" => { "version" => "0.4.1", "released" => "2026-08-14", "license" => "MIT",
                                                  "prerelease" => false, "requires_python" => ">=3.10" } },
                    "crates" => { "copula-core" => { "version" => "0.3.0", "released" => "2026-07-01",
                                                     "license" => "MIT OR Apache-2.0", "rust_version" => "1.74" } },
                    "rubygems" => { "datalog-inspect" => { "version" => "2.0.0.rc1", "license" => "MIT",
                                                           "prerelease" => true } }
                  })
      install = "{% include components/package-install.html %}"
      source.document("packages", "heavytails", install,
                      "title" => "HeavyTails", "language" => "Python", "version" => "0.2.0", "license" => "MIT",
                      "tagline" => "Heavy-tailed distributions", "github_url" => "https://github.com/example/heavytails",
                      "docs_url" => "https://heavytails.example.org/",
                      "registry" => { "pypi" => "heavytails", "conda_forge" => "heavytails" })
      source.document("packages", "copula-core", install,
                      "title" => "Copula Core", "language" => "Rust", "version" => "0.1.0",
                      "github_url" => "https://github.com/example/copula-rs", "registry" => { "crates" => "copula-core" })
      source.document("packages", "datalog-inspect", install,
                      "title" => "Datalog Inspect", "language" => "Ruby",
                      "registry" => { "rubygems" => "datalog-inspect" })
      source.document("packages", "legacy-stats",
                      '{% include components/package-install.html pip_command="pip install legacy-stats[all]" %}',
                      "title" => "Legacy Stats", "language" => "Python", "version" => "1.0.0", "status" => "beta",
                      "tagline" => "An older package", "pypi_url" => "https://pypi.org/project/legacy-stats/")
      source.document("packages", "notes", install,
                      "title" => "Notes", "language" => "Haskell", "github_url" => "https://github.com/example/notes")
      source.document("packages", "bare", install, "title" => "Bare")
      source.page("index.html", "{% include components/package-index.html %}")
      source.page("table/index.html", '{% include components/package-index.html style="table" group_by="language" %}')
    end
  end
end
