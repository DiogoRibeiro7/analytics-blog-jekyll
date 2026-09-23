# Testing Guide

What the suite is, which layer a new test belongs in, and the handful of things
about this repository that will otherwise cost you an afternoon.

- [The four layers](#the-four-layers)
- [Running them](#running-them)
- [Writing a test](#writing-a-test)
- [Fixtures](#fixtures)
- [Coverage](#coverage)
- [Continuous integration](#continuous-integration)
- [Things that will catch you out](#things-that-will-catch-you-out)
- [What the suite does not cover](#what-the-suite-does-not-cover)

## The four layers

| Layer | Where | Size | Runs in |
| --- | --- | --- | --- |
| Minitest | `tests/test_*.rb` | 68 files, 581 tests | ~112 s |
| Vitest | `tests/js/*.test.js` | 38 files, 1,094 tests | ~15 s |
| Playwright | `tests/integration/*.spec.js` | 24 files, 137 tests | builds and serves the site first |
| axe-core | `tests/integration/axe.spec.js` | 9 pages × 2 themes | part of Playwright |

Which one you want:

- **A Liquid filter, a tag, a plugin, a generator, or anything about what the
  built site contains** — Minitest. Most of what this theme does only exists
  once Jekyll has run, so the test builds a site and reads what came out.
- **A browser module under `assets/js/`** — Vitest, in jsdom.
- **Anything that needs layout, real CSS, a real network request, focus or a
  keyboard** — Playwright. If you find yourself reaching for jsdom's geometry,
  you want Playwright instead: jsdom has no layout.
- **Anything about colour, contrast or an accessible name** — the axe sweep, in
  both themes. Pa11y runs too, but it only ever sees light mode.

If the markup you care about only exists after someone has used the page, add
an entry to `INTERACT` in `tests/integration/axe.spec.js` so the sweep uses it
before scanning. The search results went unexamined for exactly that reason,
and had 17 violations when someone finally looked (#365).

## Running them

```bash
bundle install && npm install    # once

bundle exec rake test            # Minitest, builds the demo site once
npm test                         # Vitest
npm run test:integration         # Playwright: builds the site and serves it for you
```

One file, or one test:

```bash
bundle exec ruby tests/test_licenses.rb
bundle exec ruby tests/test_licenses.rb -n test_a_known_identifier_gives_a_name_and_a_url_however_it_is_spelt
bundle exec ruby tests/test_licenses.rb -n "/identifier/"   # see the Git Bash note below

npx vitest run tests/js/theme.test.js
npx vitest run -t "dark figures"          # by test name; --grep is not a vitest flag
npx vitest                                 # watch mode

PLAYWRIGHT_GREP="search" npm run test:integration
npm run test:integration -- tests/integration/search-workflow.spec.js
npm run test:integration:direct            # against an existing PLAYWRIGHT_BASE_URL
```

On Git Bash, `-n "/regex/"` matches nothing: MSYS2 reads the slashes as a path
and rewrites the argument. Use PowerShell for that form, or give the exact test
name. The same conversion catches any argument that looks like a path.

`npm run test:integration` builds the site with `tests/integration/site-config.yml`
layered over `_config.yml`, starts a static server on port 4173 and sets
`PLAYWRIGHT_BASE_URL` for you. The layered config points
`dynamic_services.base_url` at `https://api.example.test`, which the specs
answer themselves with `page.route` — see `tests/integration/corrections.spec.js`.

When something fails, Playwright keeps a trace:

```bash
npx playwright show-trace test-results/<the-failing-test>/trace.zip
```

## Writing a test

The suite has a house style. It is not enforced by a linter, so it is worth
reading a neighbouring file before adding to one.

**A test name is a sentence about behaviour**, not a label for a method:

```ruby
def test_a_heading_without_an_id_indexes_with_no_anchor
def test_the_headings_the_layout_adds_are_not_sections
```

**A comment above a test says which bug it is for and why the obvious fix was
wrong.** This is the part that pays for itself. Six months later the test looks
arbitrary without it:

```ruby
# "1. Introduction" gives id="1-introduction", which is not a valid CSS
# identifier. It is a perfectly good URL fragment, and the section link is a
# href, so it is kept exactly as written — the contents list's handler fed
# one to querySelector and the links died (#330).
def test_an_id_that_starts_with_a_digit_is_kept_as_it_is
```

**An assertion carries a message naming what failed**, because the suite builds
whole sites and "expected true to be false" tells you nothing about which page:

```ruby
assert File.exist?(path), "#{url} should be written"
assert_includes page, opening, "#{doc['url']} section #{section['title'].inspect}"
```

**Prefer a fixture that derives from the thing under test** over one that
restates it. A search fixture builds its `content` by joining its `sections`,
because that is how the index builds it — otherwise a fixture can claim a
section the page does not contain, and the test passes for the wrong reason.

## Fixtures

### The shared demo site

`SiteBuilder` builds this repository's own site once per process and 57 files
read it. Requiring `tests/test_helper.rb` does not build it; the first call to
`SiteBuilder.read`, `json`, `site` or `payload` does.

```ruby
html = SiteBuilder.read("2024/04/05/sql-optimization-guide/index.html")
index = SiteBuilder.json("search.json")
post = SiteBuilder.site.posts.docs.first
```

It is shared, so **do not mutate it**. If a test needs different configuration
or different content, it wants a site of its own.

### A site of its own

`TestSite` (in `tests/support/test_site.rb`) is the one way to build one. It
owns a temporary directory, removed at the end of the run, so a test needs no
`setup` or `teardown`:

```ruby
site = TestSite.build(title: "Licences", baseurl: "/blog") do |source|
  source.theme("_includes/components/license-notice.html", "_data/i18n")
  source.page("index.html", "{% include components/license-notice.html page=page %}",
              "date: 2024-02-20\nlicense: CC-BY-4.0\n")
end

site.html("index.html")                 # a Nokogiri fragment
site.document("index.html")             # a whole document, for a page with a layout
site.read("search.json")                # the text
site.json("search.json")
site.find("**/part-one/index.html")     # for a URL the permalink decides; nil if absent
site.exist?("feed.xml")
site.jekyll                             # the Jekyll::Site, to inspect documents
```

Writing into the source: `theme(*paths)` copies part of this repository in,
keeping where it sits; `copy(theme_path, to)` copies one file under another
name; `page`, `post`, `document(collection, …)`, `data`, `layout` and `write`
add files. Front matter is YAML text or a hash. `build(dir: earlier.dir, …)`
builds an earlier site's source again, for a test about what a second build
does.

Copy in only what the test needs. A test that renders one include copies that
include, so its dependencies are visible at the call site.

Three files deliberately do not use `TestSite`, and should stay that way:
`test_gem_consumer.rb` and `test_config_validator.rb` build sites in
subprocesses, which is the point of them, and `test_search_pages.rb`
constructs a site it never builds in order to drive one generator.

## Coverage

```bash
bundle exec rake coverage     # Minitest under SimpleCov; ~3× the runtime of rake test
npm run test:coverage         # Vitest, plus the per-module gate in scripts/check_coverage.js
```

Both write a readable report into `coverage/`. Both fail below their
thresholds, which sit a few points under the measured value so that a
regression fails and an ordinary change does not:

| | Measured | Gate | Where |
| --- | --- | --- | --- |
| Ruby lines | 84.5% | 81% | `.simplecov` |
| Ruby branches | 62.7% | 59% | `.simplecov` |
| JS statements | 91.7% | 88% | `vitest.config.js` |
| JS branches | 81.9% | 78% | `vitest.config.js` |
| JS functions | 88.6% | 83% | `vitest.config.js` |
| JS lines | 92.0% | 88% | `vitest.config.js` |

The thresholds in those two files are the authority; this table is a summary
and may lag. Coverage is reviewed each quarter — see
[coverage-review-process.md](coverage-review-process.md).

Two notes on the Ruby side. `rake coverage` merges results from the consumer
builds `test_gem_consumer.rb` runs in subprocesses, which is worth about four
points; without that merge, `lib/datalog/theme/*.rb` read 0% although they are
exercised. And `lib/datalog/theme/package.rb` and `version.rb` are filtered
out, because `bundle exec` puts `-rbundler/setup` in `RUBYOPT` and the Gemfile
says `gemspec`, so Bundler loads them at interpreter startup, before Ruby's
`Coverage` can start.

The thresholds are written for the whole suite, so `COVERAGE=1` on a single
file fails them by design. Use `rake coverage`.

## Continuous integration

`.github/workflows/test.yml` runs, on every pull request:

| Job | What |
| --- | --- |
| Unit Tests (Node 22, 24) | Vitest; the 22 leg runs coverage and enforces the gate |
| Jekyll Build & Ruby Tests | A full site build, then Minitest |
| Ruby Tests (Ruby 3.3, 3.4) | Minitest; the 3.4 leg runs coverage and enforces the gate |
| Browser Tests | Playwright, including the axe sweep |

`accessibility.yml` runs Pa11y, `lighthouse.yml` the performance budgets, and
`codeql.yml` static analysis. [TESTING.md](../TESTING.md) has the full map of
which workflows gate a merge and which run on a schedule.

Two things behave differently on CI. The image-variant tests skip their real
encoder case unless ImageMagick and `avifenc` are installed, which the workflow
does, setting `DATALOG_IMAGE_TOOLS=required` so it cannot skip silently. And
the Playwright specs also run in the deploy after a merge, against the site
that is about to be published.

## Things that will catch you out

**The script bundles have to be current.** `assets/js/dist` is checked against
its sources during the build, so after any change under `assets/js/`,
`test_gem_consumer.rb` fails until you run `npm run build:js`. It reads like a
broken test and is a guard working correctly.

**The demo site is shared and must not be mutated.** 57 files read it.

**Everything shares one process.** A test that replaces a method —
`Jekyll::ImageOptimizer.tools`, the CLI's `system` — must restore it in an
`ensure`, or it leaks into every test that follows.

**A test that builds a site and reads image markup depends on the machine.**
Without ImageMagick an image has one variant; with it, three, and the AVIF one
comes first. Stand an encoder in rather than assert whatever your machine
produces — `tests/test_image_variants.rb` has `fake_encoders`, and
`tests/test_dark_image_variants.rb` stubs `Jekyll::ImageOptimizer.tools`.

**`scroll-behavior: smooth`.** A Playwright assertion about a fragment link
cannot measure the scroll position after `load`; the jump is animated and has
not started. Wait for the element to be in the viewport instead.

**A heading id may start with a digit.** `## 1. Introduction` gives
`id="1-introduction"`, which is a valid URL fragment and an invalid CSS
identifier. Use `getElementById`, never `querySelector('#' + id)`.

**Coverage cannot see a file loaded before it starts.** If a file reads 0% and
you are sure it is tested, ask what loaded it — Bundler, a subprocess, or the
gemspec.

## What the suite does not cover

Worth knowing, so its silence is not read as assurance:

- **One browser.** Playwright runs Chromium only, at desktop size.
- **No visual regression testing**, in any layer.
- **Pa11y only sees light mode.** Dark mode is covered by the axe sweep, which
  runs both.

---

Found a gap? [CONTRIBUTING.md](../CONTRIBUTING.md) has the workflow. A test
that demonstrates a bug, committed before the fix, is the most useful kind.
