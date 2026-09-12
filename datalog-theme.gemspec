# frozen_string_literal: true

require_relative "lib/datalog/theme/version"

Gem::Specification.new do |spec|
  spec.name          = "datalog-theme"
  spec.version       = Datalog::Theme::VERSION
  spec.authors       = ["Diogo Ribeiro"]
  spec.email         = ["diogo.debastos.ribeiro@gmail.com", "dfr@esmad.ipp.pt"]

  spec.summary       = "Accessible data science Jekyll theme for research blogs and portfolios"
  spec.description   = "Modern academic Jekyll theme optimized for notebooks, visualizations, reproducibility, and technical storytelling."
  spec.homepage      = "https://github.com/DiogoRibeiro7/analytics-blog-jekyll"
  spec.license       = "MIT"

  spec.metadata["homepage_uri"]      = spec.homepage
  spec.metadata["source_code_uri"]   = spec.homepage
  spec.metadata["bug_tracker_uri"]   = "https://github.com/DiogoRibeiro7/analytics-blog-jekyll/issues"
  spec.metadata["documentation_uri"] = "https://github.com/DiogoRibeiro7/analytics-blog-jekyll#readme"
  spec.metadata["changelog_uri"]     = "https://github.com/DiogoRibeiro7/analytics-blog-jekyll/releases"
  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["jekyll-theme"]      = "datalog"
  spec.metadata["plugin_type"]       = "theme"
  spec.metadata["orcid"]             = "https://orcid.org/0009-0001-2022-7072"

  spec.required_ruby_version = ">= 3.0"
  spec.require_paths = ["lib"]
  spec.bindir = "bin"
  spec.executables = ["datalog"]

  # Ship only theme infrastructure — not demo content (_posts, _pages, _portfolio,
  # _datasets, _packages, _notebooks, tests, docs, scripts, CI configs, frontend
  # tooling, Dockerfiles, etc.). Theme consumers get layouts/includes/sass/assets/
  # plugins/data/lib/bin and the licensing/changelog metadata.
  spec.files = Dir.chdir(__dir__) do
    tracked = `git ls-files -z`.split("\x0").select do |f|
      f.match?(%r{\A(?:_layouts|_includes|_sass|_plugins|_data|assets|lib|bin)/}) ||
        %w[
          LICENSE
          README.md
          CHANGELOG.md
          CITATION.cff
          datalog-theme.gemspec
        ].include?(f)
    end

    # The browser bundles are build output, so git does not track them, but
    # _data/js_manifest.json points every page at them: a gem without them
    # gives consumers a site whose scripts all 404. Run `npm run build:js`
    # before packaging; scripts/verify_gem_package.rb checks the result.
    built = Dir.glob("assets/js/dist/**/*").select { |f| File.file?(f) }

    (tracked + built).uniq.sort
  end

  spec.add_runtime_dependency "jekyll", "~> 4.3"
  spec.add_runtime_dependency "jekyll-sass-converter", "~> 3.0"
  spec.add_runtime_dependency "jekyll-feed", ">= 0.16"
  spec.add_runtime_dependency "jekyll-seo-tag", ">= 2.8"
  spec.add_runtime_dependency "jekyll-sitemap", ">= 1.4"
  spec.add_runtime_dependency "sass-embedded", ">= 1.71"
  spec.add_runtime_dependency "jekyll-paginate", ">= 1.1"
  spec.add_runtime_dependency "jekyll-include-cache", ">= 0.2"
  spec.add_runtime_dependency "jekyll-archives", ">= 2.2"
  spec.add_runtime_dependency "jekyll-remote-theme", ">= 0.4"
  spec.add_runtime_dependency "jekyll-redirect-from", ">= 0.16"
  spec.add_runtime_dependency "kramdown-parser-gfm", ">= 1.1"
  spec.add_runtime_dependency "webrick", ">= 1.8"
  spec.add_runtime_dependency "fastimage", ">= 2.2"
  spec.add_runtime_dependency "loofah", ">= 2.19"
  spec.add_runtime_dependency "nokogiri", ">= 1.15"
  spec.add_runtime_dependency "mini_magick", ">= 4.12"
  spec.add_runtime_dependency "logger", ">= 1.6"
  spec.add_runtime_dependency "thor", ">= 1.3"
  spec.add_runtime_dependency "googleauth", ">= 1.9"

  spec.add_development_dependency "bundler", ">= 2.4"
  spec.add_development_dependency "rake", ">= 13.0"
  spec.add_development_dependency "minitest", "~> 6.0"
end
