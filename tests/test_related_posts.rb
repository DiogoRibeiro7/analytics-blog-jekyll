# frozen_string_literal: true

require_relative "test_helper"

# The related posts list was built from `site.posts | split: ''`, which turned
# the list into single characters, so every post said "No related posts yet".
class RelatedPostsTest < Minitest::Test
  POST = "2024/04/05/sql-optimization-guide/index.html"

  def test_lists_posts_that_share_a_tag
    refute_includes related, "No related posts yet"
    assert_includes related, 'href="/tutorials/2024/02/10/sql-analytics-guide/"',
                    "the SQL analytics guide shares the sql tag"
  end

  def test_leaves_out_the_post_itself_and_stops_at_the_limit
    refute_includes related, 'href="/2024/04/05/sql-optimization-guide/"'
    assert_operator related.scan("<li>").size, :<=, 3
  end

  private

  def related
    @related ||= SiteBuilder.read(POST)[%r{<section class="post-related".*?</section>}m].to_s
  end
end
