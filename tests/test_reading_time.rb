# frozen_string_literal: true

require_relative "test_helper"

class ReadingTimeFilterTest < Minitest::Test
  SAMPLE_POST = "2024/01/01/introducing-datalog/index.html"

  def setup
    @filter = Object.new
    @filter.extend(Jekyll::ReadingTimeFilter)
  end

  def test_short_content_returns_one_minute
    assert_equal 1, @filter.reading_time("hello world")
  end

  def test_180_words_returns_one_minute
    content = (["word"] * 180).join(" ")
    assert_equal 1, @filter.reading_time(content)
  end

  def test_360_words_returns_two_minutes
    content = (["word"] * 360).join(" ")
    assert_equal 2, @filter.reading_time(content)
  end

  def test_empty_string_returns_one
    assert_equal 1, @filter.reading_time("")
  end

  def test_nil_input_returns_one
    assert_equal 1, @filter.reading_time(nil)
  end

  def test_181_words_rounds_up_to_two_minutes
    content = (["word"] * 181).join(" ")
    assert_equal 2, @filter.reading_time(content)
  end

  def test_post_has_reading_time_in_built_site
    html = SiteBuilder.read(SAMPLE_POST)
    assert_match(/data-reading-time/, html,
                 "Built post should include a reading-time element rendered by the filter")
  end
end
