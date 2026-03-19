# frozen_string_literal: true

require_relative "test_helper"

class WarningFilterTest < Minitest::Test
  def test_filters_constant_defined
    assert defined?(Datalog::WarningFilter::FILTERS),
           "FILTERS constant should be defined"
    assert_kind_of Array, Datalog::WarningFilter::FILTERS
    assert Datalog::WarningFilter::FILTERS.frozen?, "FILTERS should be frozen"
  end

  def test_filters_include_frozen_string_pattern
    patterns = Datalog::WarningFilter::FILTERS
    frozen_pattern = patterns.find { |p| p.match?("literal string will be frozen") }
    refute_nil frozen_pattern, "FILTERS should include a pattern for frozen string warnings"
  end

  def test_filters_include_version_constant_pattern
    patterns = Datalog::WarningFilter::FILTERS
    version_pattern = patterns.find { |p| p.match?("already initialized constant Datalog::Theme::VERSION") }
    refute_nil version_pattern, "FILTERS should include a pattern for VERSION reinitialization warnings"
  end

  def test_suppresses_frozen_string_warning
    output = capture_warnings do
      warn "warning: literal string will be frozen in the future"
    end
    assert_empty output, "Frozen string warning should be suppressed"
  end

  def test_suppresses_version_constant_warning
    output = capture_warnings do
      warn "already initialized constant Datalog::Theme::VERSION"
    end
    assert_empty output, "VERSION constant warning should be suppressed"
  end

  def test_allows_unmatched_warnings_through
    output = capture_warnings do
      warn "something completely different"
    end
    assert_includes output, "something completely different",
                    "Non-matching warnings should pass through"
  end

  def test_allows_regular_deprecation_warnings
    output = capture_warnings do
      warn "DEPRECATION WARNING: method foo is deprecated"
    end
    assert_includes output, "DEPRECATION WARNING",
                    "Regular deprecation warnings should not be suppressed"
  end

  def test_kernel_warn_suppresses_matching_messages
    output = capture_warnings do
      Kernel.warn("literal string will be frozen in the future")
    end
    assert_empty output, "Kernel.warn should suppress matching messages"
  end

  def test_kernel_warn_passes_non_matching_messages
    output = capture_warnings do
      Kernel.warn("normal warning message")
    end
    assert_includes output, "normal warning message",
                    "Kernel.warn should pass non-matching messages"
  end

  def test_warning_module_prepended
    assert Warning.singleton_class.ancestors.include?(Datalog::WarningFilter),
           "Datalog::WarningFilter should be prepended to Warning singleton class"
  end

  private

  def capture_warnings
    old_stderr = $stderr
    $stderr = StringIO.new
    yield
    $stderr.string
  ensure
    $stderr = old_stderr
  end
end
