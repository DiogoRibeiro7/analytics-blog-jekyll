# frozen_string_literal: true

require_relative "test_helper"
require_relative "csp_policy_helpers"

# What the policy of a page with an embed or generated content allows.
class ContentSecurityPolicyPagesTest < Minitest::Test
  include CspPolicyHelpers

  # Notebook pages are created by a generator that runs after nonces are
  # assigned. Their templates printed an empty page.csp_nonce, so the browser
  # refused every inline script in their head.
  def test_every_nonce_in_a_page_matches_its_policy
    %w[notebooks/sample-analysis/index.html index.html 2024/01/01/introducing-datalog/index.html].each do |page|
      html = SiteBuilder.read(page)
      nonce_source = policy_directives(html)["script-src"].find { |source| source.start_with?("'nonce-") }
      policy_nonce = nonce_source.to_s[/'nonce-(.+)'/, 1]
      refute_nil policy_nonce, "#{page} should have a nonce in its policy"

      nonces = html.scan(/<(?:script|style)\b[^>]*\bnonce="([^"]*)"/i).flatten.uniq
      assert_equal [policy_nonce], nonces, "Every nonce in #{page} should be the one its policy names"
    end
  end

  # MathJax's CHTML output inserts the <style> element its layout depends on.
  def test_mathjax_pages_allow_the_styles_mathjax_inserts
    directives = policy_directives(SiteBuilder.read("2024/01/01/introducing-datalog/index.html"))

    assert_includes directives["style-src"], "'unsafe-inline'"
  end

  # An observablehq.com embed redirects to old.observablehq.com, which the
  # policy refused.
  def test_frame_src_allows_observable_classic_embeds
    assert_includes policy_directives(SiteBuilder.read("visualizations/index.html"))["frame-src"],
                    "https://old.observablehq.com"
  end

  def test_disqus_pages_allow_the_disqus_embed
    directives = policy_directives(SiteBuilder.read("2024/04/10/disqus-csp-verification/index.html"))

    assert_includes directives["script-src"], "https://*.disqus.com"
    assert_includes directives["frame-src"], "https://disqus.com"
    refute_includes policy_directives(SiteBuilder.read("index.html"))["script-src"], "https://*.disqus.com"
  end
end
