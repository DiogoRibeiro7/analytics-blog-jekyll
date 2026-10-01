# frozen_string_literal: true

require "fileutils"
require "json"
require "net/http"
require "uri"
require "yaml"
require_relative "../packages"
require_relative "../site_config"
require_relative "../theme/version"

module Datalog
  module Packages
    # `datalog packages refresh`: reads the latest release of every package the
    # site lists from each registry it names, and writes them to
    # _data/package_releases.yml for the package layout to read. The build
    # itself never goes to a registry, so it stays offline and two builds of
    # one commit match. A registry that cannot be read stops the command before
    # the file is touched. The file holds nothing but the releases, so it
    # changes only when one does, and a scheduled run has nothing to propose
    # otherwise.
    class Refresh
      class Error < StandardError; end

      USER_AGENT = "datalog-theme/#{Datalog::Theme::VERSION} (+https://github.com/DiogoRibeiro7/analytics-blog-jekyll)".freeze
      HEADER = "# The latest release of each package on each registry, written by\n" \
               "# `bundle exec datalog packages refresh`. Run it again to update this file;\n" \
               "# a package's registries are set in its front matter (`registry:`).\n"

      attr_reader :root

      # `fetch` takes a URL and returns [status, body]; the default asks the network.
      def initialize(root:, fetch: nil)
        @root = File.expand_path(root)
        @fetch = fetch || method(:http_get)
      end

      def config
        @config ||= Datalog::SiteConfig.load(File.join(root, "_config.yml"))
      end

      def data_file
        File.join(root, config["data_dir"] || "_data", "package_releases.yml")
      end

      # {"pypi" => {"name" => release}}, read from every registry, or Error
      # naming each registry that could not be read.
      def releases
        found = Hash.new { |hash, key| hash[key] = {} }
        failures = []
        packages.each do |file, data|
          Packages.registries(data).each do |registry, name|
            next unless ENDPOINTS.key?(registry)

            found[registry][name] = read(registry, name)
          rescue Error => e
            failures << "#{file}: #{e.message}"
          end
        end
        raise Error, "No release was written, because #{failures.join('; ')}" unless failures.empty?

        found.sort.to_h.transform_values { |names| names.sort.to_h }
      end

      # Writes the file and returns the releases, or raises before writing.
      # With no release to write, it leaves the file alone.
      def run(dry_run: false)
        data = releases
        yaml = HEADER + YAML.dump(data).sub(/\A---\n/, "")
        unless dry_run || data.empty?
          FileUtils.mkdir_p(File.dirname(data_file))
          File.write(data_file, yaml)
        end
        [data, yaml]
      end

      # [relative path, front matter] of each document in the packages collection.
      def packages
        directory = File.join(root, config["collections_dir"].to_s, "_packages")
        Dir.glob(File.join(directory, "**", "*.{md,markdown,html}")).filter_map do |path|
          text = File.read(path, encoding: "bom|utf-8")
          front = text[/\A---\s*\n(.*?)^---\s*$/m, 1]
          data = front && YAML.safe_load(front, permitted_classes: [Date, Time], aliases: true)
          [path.delete_prefix("#{root}/"), data] if data.is_a?(Hash)
        end
      end

      def read(registry, name)
        url = format(ENDPOINTS.fetch(registry), URI.encode_www_form_component(name))
        status, body = begin
          @fetch.call(url)
        rescue StandardError => e
          raise Error, "could not reach #{REGISTRIES.dig(registry, :label)} at #{url} (#{e.message})"
        end
        if status == 404
          raise Error, "#{REGISTRIES.dig(registry, :label)} has no package named #{name} (#{url})"
        elsif !(200..299).cover?(status.to_i)
          raise Error, "#{REGISTRIES.dig(registry, :label)} answered #{status} for #{name} (#{url})"
        end

        Releases.public_send(registry, JSON.parse(body))
      rescue JSON::ParserError, KeyError, NoMethodError, TypeError => e
        raise Error,
              "#{REGISTRIES.dig(registry, :label)} sent an answer for #{name} that is not a release (#{e.message})"
      end

      def http_get(url)
        uri = URI(url)
        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 10,
                                            read_timeout: 20) do |http|
          request = Net::HTTP::Get.new(uri)
          request["User-Agent"] = USER_AGENT
          request["Accept"] = "application/json"
          response = http.request(request)
          [response.code.to_i, response.body]
        end
      end
    end

    # One registry's answer as one release: version, released (a date),
    # license, the language it needs, and whether it is a pre-release or yanked.
    module Releases
      module_function

      def pypi(json)
        info = json.fetch("info")
        version = info.fetch("version")
        files = Array(json.dig("releases", version) || json["urls"])
        license = info["license_expression"].to_s
        license = info["license"].to_s if license.empty? && info["license"].to_s.length.between?(1, 40)
        license = classifier_license(info["classifiers"]) if license.empty?
        release(version, files.map { |file| file["upload_time_iso_8601"] || file["upload_time"] }.compact.min,
                license, "requires_python" => info["requires_python"],
                         "yanked" => !files.empty? && files.all? { |file| file["yanked"] })
      end

      def crates(json)
        crate = json.fetch("crate")
        version = crate["max_stable_version"] || crate["newest_version"] || crate.fetch("max_version")
        found = Array(json["versions"]).find { |entry| entry["num"] == version } || {}
        release(version, found["created_at"], found["license"],
                "rust_version" => found["rust_version"], "yanked" => found["yanked"] == true)
      end

      def rubygems(json)
        versions = Array(json)
        found = versions.find { |entry| entry["prerelease"] != true } || versions.fetch(0)
        release(found.fetch("number"), found["created_at"], Array(found["licenses"]).join(", "),
                "required_ruby_version" => found["ruby_version"])
      end

      def cran(json)
        depends = json["Depends"]
        r_version = depends.is_a?(Hash) ? depends["R"] : depends.to_s[/\bR\s*\(([^)]+)\)/, 1]
        release(json.fetch("Version"), json["Date/Publication"], json["License"], "r_version" => r_version)
      end

      def npm(json)
        version = json.dig("dist-tags", "latest") || raise(KeyError, "no latest version")
        found = json.dig("versions", version) || {}
        license = found["license"].is_a?(Hash) ? found.dig("license", "type") : found["license"]
        release(version, json.dig("time", version), license, "node_version" => found.dig("engines", "node"),
                                                             "yanked" => !found["deprecated"].to_s.empty?)
      end

      def release(version, released, license, extra = {})
        date = released.to_s[/\A\d{4}-\d{2}-\d{2}/]
        found = { "version" => version.to_s, "released" => date, "license" => blank(license),
                  "prerelease" => Packages.prerelease?(version) }
        found.merge(extra.transform_values { |value| blank(value) })
             .reject { |key, value| value.nil? || (key == "yanked" && !value) }
      end

      def blank(value)
        return value if [true, false].include?(value)

        text = value.to_s.strip
        text.empty? ? nil : text
      end

      def classifier_license(classifiers)
        Array(classifiers).filter_map { |entry| entry[/\ALicense :: (?:OSI Approved :: )?(.+)\z/, 1] }.first.to_s
      end
    end
  end
end
