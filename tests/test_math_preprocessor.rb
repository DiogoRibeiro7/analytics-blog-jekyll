# frozen_string_literal: true

require_relative "test_helper"

class MathPreprocessorTest < Minitest::Test
  SAMPLE_POST = "2024/01/01/introducing-datalog/index.html"

  def test_inline_dollar_math_wrapped_in_span
    processor = MathPreprocessor::Processor.new("The value $x^2$ is important.")
    result = processor.process
    assert_match(/<span [^>]*class="math-expression-inline[^"]*"[^>]*>\$x\^2\$<\/span>/, result,
                 "Inline dollar math should be wrapped in a span")
  end

  def test_display_dollar_math_wrapped_in_div
    processor = MathPreprocessor::Processor.new("Consider $$E=mc^2$$ here.")
    result = processor.process
    assert_match(/<div [^>]*class="math-expression[^"]*"[^>]*>.*E=mc\^2.*<\/div>/, result,
                 "Display dollar math should be wrapped in a div")
    refute_match(/<p>.*\$\$E=mc\^2\$\$.*<\/p>/, result,
                 "Raw display math should not survive without wrapping")
  end

  def test_inline_paren_syntax_wrapped_in_span
    processor = MathPreprocessor::Processor.new('Result is \(a+b\) done.')
    result = processor.process
    assert_match(/<span [^>]*class="math-expression-inline[^"]*"[^>]*>/, result,
                 'Inline \\(...\\) math should be wrapped in a span')
    assert_includes result, '\(a+b\)',
                    "Original delimiters should be preserved inside the wrapper"
  end

  def test_display_bracket_syntax_wrapped_in_div
    processor = MathPreprocessor::Processor.new('Formula: \[a+b=c\] end.')
    result = processor.process
    assert_match(/<div [^>]*class="math-expression[^"]*"[^>]*>/, result,
                 'Display \\[...\\] math should be wrapped in a div')
    assert_includes result, '\[a+b=c\]',
                    "Original delimiters should be preserved inside the wrapper"
  end

  def test_content_without_math_is_unchanged
    plain = "This is a paragraph without any mathematical notation."
    processor = MathPreprocessor::Processor.new(plain)
    result = processor.process
    assert_equal plain, result, "Content without math should pass through unchanged"
  end

  def test_nil_content_is_handled
    processor = MathPreprocessor::Processor.new(nil)
    result = processor.process
    assert_nil result, "Nil content should be returned as-is"
  end

  def test_data_math_source_attribute_present
    processor = MathPreprocessor::Processor.new("Value $y=3$ here.")
    result = processor.process
    assert_match(/data-math-source="y=3"/, result,
                 "Wrapped math should include data-math-source with cleaned LaTeX")
  end

  def test_aria_label_attribute_present
    processor = MathPreprocessor::Processor.new("Value $y=3$ here.")
    result = processor.process
    assert_match(/aria-label="[^"]*"/, result,
                 "Wrapped math should include an aria-label for accessibility")
  end

  def test_expressions_are_recorded
    processor = MathPreprocessor::Processor.new("First $a$ and $$b+c$$ done.")
    processor.process
    assert_operator processor.expressions.size, :>=, 2,
                    "Processor should record all math expressions found"
  end

  def test_built_post_has_math_wrappers
    html = SiteBuilder.read(SAMPLE_POST)
    assert_match(/class="math-expression/, html,
                 "Built post with math should contain preprocessor wrappers")
  end

  # Dollar signs in code used to be wrapped as math, inserting markup into
  # shell, R and SQL snippets.
  def test_dollar_signs_in_fenced_code_stay_literal
    source = "Math $x^2$ here.\n\n```bash\necho $HOME and $PATH\n```\n"
    result = MathPreprocessor::Processor.new(source).process

    assert_includes result, "```bash\necho $HOME and $PATH\n```"
    assert_match(/math-expression-inline[^>]*>\$x\^2\$</, result, "math outside the code is still wrapped")
  end

  def test_dollar_signs_in_inline_code_stay_literal
    source = "Run `echo $HOME and $PATH` first."
    assert_equal source, MathPreprocessor::Processor.new(source).process
  end

  def test_dollar_signs_in_highlight_blocks_stay_literal
    source = "{% highlight r %}\ndf$col + df$other\n{% endhighlight %}"
    assert_equal source, MathPreprocessor::Processor.new(source).process
  end

  def test_prices_stay_text
    source = "It costs $5 a month, or $50 a year."
    assert_equal source, MathPreprocessor::Processor.new(source).process
  end
end
