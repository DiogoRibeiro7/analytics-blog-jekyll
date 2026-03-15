# frozen_string_literal: true

require "json"
require "net/http"
require "time"
require "stringio"
require "fileutils"

module Datalog
  module Analytics
    GA_SCOPE = "https://www.googleapis.com/auth/analytics.readonly"
    CACHE_RELATIVE_PATH = ".jekyll-cache/datalog-analytics.json"
    CACHE_TTL = 24 * 60 * 60
    HTTP_TIMEOUTS = { open: 5, read: 15, write: 15 }.freeze
    HTTP_MAX_RETRIES = 2
    RETRYABLE_ERRORS = [
      Timeout::Error,
      Errno::ECONNRESET,
      Errno::ETIMEDOUT,
      SocketError,
      Net::OpenTimeout,
      Net::ReadTimeout
    ].freeze

    module_function

    def fetch(site)
      cache_path = cache_path_for(site)
      cached = read_cache(cache_path)
      if fresh?(cached)
        return cached
      end

      data = query_analytics(site)
      data["fetched_at"] = Time.now.utc.iso8601
      write_cache(cache_path, data)
      data
    rescue StandardError => e
      Jekyll.logger.warn("Analytics", "Falling back to cached analytics data: #{e.message}")
      cached || fallback_payload("error", e.message)
    end

    def cache_path_for(site)
      File.join(site.source, CACHE_RELATIVE_PATH)
    end

    def fresh?(payload)
      return false unless payload.is_a?(Hash)

      fetched_at = payload["fetched_at"]
      return false if fetched_at.to_s.empty?

      Time.parse(fetched_at) > Time.now - CACHE_TTL
    rescue ArgumentError
      false
    end

    def read_cache(path)
      return unless File.exist?(path)

      JSON.parse(File.read(path))
    rescue JSON::ParserError
      nil
    end

    def write_cache(path, payload)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, JSON.pretty_generate(payload))
    rescue StandardError => e
      Jekyll.logger.warn("Analytics", "Unable to persist analytics cache: #{e.message}")
    end

    def query_analytics(site)
      config = site.config.fetch("analytics", {})
      property_id = ENV["GA4_PROPERTY_ID"] || config["ga4_property_id"]
      credentials_json = credentials_payload(config)

      unless property_id && !property_id.empty?
        return fallback_payload("missing_configuration", "Set GA4_PROPERTY_ID to enable analytics dashboards.")
      end

      unless credentials_json
        return fallback_payload("missing_credentials", "Provide GA4 service account credentials to query the Analytics API.")
      end

      token = fetch_access_token(credentials_json)

      requests = build_requests
      results = {}
      requests.each do |key, body|
        results[key] = run_report(property_id, token, body)
      end

      enrich_with_monthly_reports!(results)
      inject_scholar_metrics!(results, site)
      results["status"] = "ok"
      results
    rescue LoadError => e
      fallback_payload("missing_dependency", "Install googleauth to enable GA4 integration: #{e.message}")
    rescue StandardError => e
      fallback_payload("error", e.message)
    end

    def credentials_payload(config)
      json = ENV["GA4_CREDENTIALS_JSON"]
      return json unless json.to_s.strip.empty?

      path = ENV["GA4_CREDENTIALS_PATH"] || config["ga4_credentials_path"]
      if path && File.exist?(path)
        return File.read(path)
      end

      config_json = config["ga4_credentials_json"]
      return config_json unless config_json.to_s.strip.empty?

      nil
    end

    def fetch_access_token(credentials_json)
      require "googleauth"

      credentials = Google::Auth::ServiceAccountCredentials.make_creds(
        scope: GA_SCOPE,
        json_key_io: StringIO.new(credentials_json)
      )
      credentials.fetch_access_token!
      credentials.access_token
    end

    def build_requests
      {
        "top_posts" => {
          "dimensions" => [{ "name" => "pagePath" }],
          "metrics" => [
            { "name" => "screenPageViews" },
            { "name" => "userEngagementDuration" }
          ],
          "dateRanges" => [{ "startDate" => "28daysAgo", "endDate" => "today" }],
          "limit" => 10,
          "orderBys" => [{ "metric" => { "metricName" => "screenPageViews" }, "desc" => true }]
        },
        "search_terms" => {
          "dimensions" => [{ "name" => "searchTerm" }],
          "metrics" => [{ "name" => "sessions" }],
          "dateRanges" => [{ "startDate" => "28daysAgo", "endDate" => "today" }],
          "limit" => 10,
          "orderBys" => [{ "metric" => { "metricName" => "sessions" }, "desc" => true }]
        },
        "visitor_trends" => {
          "dimensions" => [{ "name" => "date" }],
          "metrics" => [
            { "name" => "totalUsers" },
            { "name" => "newUsers" },
            { "name" => "sessions" },
            { "name" => "screenPageViews" }
          ],
          "dateRanges" => [{ "startDate" => "90daysAgo", "endDate" => "today" }],
          "orderBys" => [{ "dimension" => { "dimensionName" => "date" } }]
        },
        "engagement_by_page" => {
          "dimensions" => [{ "name" => "pagePath" }],
          "metrics" => [
            { "name" => "screenPageViews" },
            { "name" => "averageSessionDuration" },
            { "name" => "engagedSessions" }
          ],
          "dateRanges" => [{ "startDate" => "28daysAgo", "endDate" => "today" }],
          "limit" => 20,
          "orderBys" => [{ "metric" => { "metricName" => "engagedSessions" }, "desc" => true }]
        },
        "key_events" => {
          "dimensions" => [{ "name" => "eventName" }],
          "metrics" => [{ "name" => "eventCount" }],
          "dimensionFilter" => {
            "filter" => {
              "inListFilter" => {
                "dimensionName" => "eventName",
                "values" => ["notebook_download", "demo_launch"]
              }
            }
          },
          "dateRanges" => [{ "startDate" => "28daysAgo", "endDate" => "today" }],
          "limit" => 10,
          "orderBys" => [{ "metric" => { "metricName" => "eventCount" }, "desc" => true }]
        }
      }
    end

    def run_report(property_id, token, body)
      uri = URI("https://analyticsdata.googleapis.com/v1beta/properties/#{property_id}:runReport")
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{token}"
      request["Content-Type"] = "application/json"
      request.body = JSON.dump(body)

      response = perform_http_request(uri) { |http| http.request(request) }

      unless response.is_a?(Net::HTTPSuccess)
        raise "GA4 API error: #{response.code} #{response.body}"
      end

      JSON.parse(response.body)
    end

    def enrich_with_monthly_reports!(results)
      trend_rows = extract_rows(results.fetch("visitor_trends", {}))
      monthly = Hash.new do |hash, key|
        hash[key] = {
          "total_users" => 0,
          "new_users" => 0,
          "sessions" => 0,
          "page_views" => 0
        }
      end

      trend_rows.each do |row|
        month = row.dig("dimensionValues", 0, "value")&.to_s&.slice(0, 6)
        next unless month

        data = monthly[month]
        metrics = row["metricValues"] || []
        data["total_users"] += metrics.fetch(0, {})["value"].to_f
        data["new_users"] += metrics.fetch(1, {})["value"].to_f
        data["sessions"] += metrics.fetch(2, {})["value"].to_f
        data["page_views"] += metrics.fetch(3, {})["value"].to_f
      end

      reports = monthly.keys.sort.reverse.map do |month|
        {
          "month" => format_month(month),
          "total_users" => monthly[month]["total_users"].round,
          "new_users" => monthly[month]["new_users"].round,
          "sessions" => monthly[month]["sessions"].round,
          "page_views" => monthly[month]["page_views"].round
        }
      end

      results["monthly_reports"] = reports
    end

    def format_month(key)
      return key unless key && key.length == 6

      year = key[0, 4]
      month = key[4, 2]
      "#{year}-#{month}"
    end

    def inject_scholar_metrics!(results, site)
      academic = site.data["academic"] || {}
      citations = academic.fetch("citations", {})
      metrics = citations.fetch("metrics", {})
      results["scholar"] = {
        "total" => metrics["total"],
        "h_index" => metrics["h_index"],
        "i10_index" => metrics["i10_index"],
        "since_2019" => metrics.fetch("since_2019", {}),
        "yearly_totals" => citations.fetch("yearly_totals", {})
      }
      results
    end

    def extract_rows(response)
      return [] unless response.is_a?(Hash)

      response.fetch("rows", [])
    end

    def fallback_payload(status, message)
      {
        "status" => status,
        "message" => message,
        "top_posts" => { "rows" => [] },
        "search_terms" => { "rows" => [] },
        "visitor_trends" => { "rows" => [] },
        "engagement_by_page" => { "rows" => [] },
        "key_events" => { "rows" => [] },
        "monthly_reports" => [],
        "scholar" => {}
      }
    end

    def perform_http_request(uri)
      attempts = 0
      begin
        attempts += 1
        Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
          apply_timeouts(http)
          yield(http)
        end
      rescue *RETRYABLE_ERRORS => e
        raise if attempts > HTTP_MAX_RETRIES

        Jekyll.logger.warn(
          "Analytics",
          "Retrying GA4 request (attempt #{attempts}): #{e.class}: #{e.message}"
        )
        sleep(0.25 * attempts)
        retry
      end
    end

    def apply_timeouts(http)
      http.open_timeout = HTTP_TIMEOUTS[:open]
      http.read_timeout = HTTP_TIMEOUTS[:read]
      if http.respond_to?(:write_timeout=) && HTTP_TIMEOUTS[:write]
        http.write_timeout = HTTP_TIMEOUTS[:write]
      end
    end
  end

  class AnalyticsDashboardGenerator < Jekyll::Generator
    safe true
    priority :low

    def generate(site)
      site.data["analytics_dashboard"] = Analytics.fetch(site)
    end
  end
end
