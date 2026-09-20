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
    processor = MathPreprocessor::Processor.new("Consider the equation:\n\n$$E=mc^2$$\n")
    result = processor.process
    assert_match(/<div [^>]*class="math-expression[^"]*"[^>]*>.*E=mc\^2.*<\/div>/, result,
                 "Display dollar math should be wrapped in a div")
    refute_match(/<p>.*\$\$E=mc\^2\$\$.*<\/p>/, result,
                 "Raw display math should not survive without wrapping")
  end

  def test_inline_double_dollar_math_survives_markdown_without_visible_html
    source = 'Consider $$X_t$$ where $$t \\leq \\tau$$ and $$X_t \\sim F_0$$.'
    processor = MathPreprocessor::Processor.new(source)
    html = SiteBuilder.site.find_converter_instance(Jekyll::Converters::Markdown).convert(processor.process)
    document = Nokogiri::HTML.fragment(html)

    assert_equal 3, document.css("p > span.math-expression-inline").size
    assert_equal 3, processor.expressions.size
    assert_empty document.css("div.math-expression")
    refute_includes document.text, "<div"
    refute_includes document.text, "<span"
    assert_includes document.text, '$t \\leq \\tau$'
  end

  def test_inline_double_dollars_at_sentence_boundaries_and_in_lists
    ["$$x$$ is the value.", "The value is $$x$$", "- $$x$$", "### Variable $$x$$"].each do |source|
      result = MathPreprocessor::Processor.new(source).process
      assert_match(/<span [^>]*class="math-expression-inline/, result)
      assert_includes result, "$x$"
      refute_includes result, "<div"
    end
  end

  def test_empty_double_dollar_pair_stays_literal
    source = "Keep $$   $$ as text."
    assert_equal source, MathPreprocessor::Processor.new(source).process
  end

  def test_inline_double_dollars_do_not_consume_display_equations_or_code
    source = "At $$x$$ we have:\n\n$$\nx+y=z\n$$\n\nThen $$y$$.\n\n```tex\n$$literal$$\n```\n"
    processor = MathPreprocessor::Processor.new(source)
    result = processor.process
    html = SiteBuilder.site.find_converter_instance(Jekyll::Converters::Markdown).convert(result)
    document = Nokogiri::HTML.fragment(html)

    assert_equal 2, document.css("span.math-expression-inline").size
    assert_equal 1, document.css("div.math-expression").size
    assert_equal 3, processor.expressions.size
    assert_includes document.at_css("code").text, "$$literal$$"
    assert_includes result, "$$\nx+y=z\n$$"
    refute_includes document.text, "<div"
  end

  def test_inline_paren_syntax_wrapped_in_span
    processor = MathPreprocessor::Processor.new('Result is \(a+b\) done.')
    result = processor.process
    assert_match(/<span [^>]*class="math-expression-inline[^"]*"[^>]*>/, result,
                 'Inline \\(...\\) math should be wrapped in a span')
    assert_includes result, '\(a+b\)',
                    "Original delimiters should be preserved inside the wrapper"
  end

  def test_inline_tex_survives_markdown_conversion
    source = 'A value \(x<y\), \(\mu\), and $a_b_c$.'
    wrapped = MathPreprocessor::Processor.new(source).process
    html = SiteBuilder.site.find_converter_instance(Jekyll::Converters::Markdown).convert(wrapped)
    nodes = Nokogiri::HTML.fragment(html).css(".math-expression-inline")
    assert_equal ['\(x<y\)', '\(\mu\)', "$a_b_c$"], nodes.map(&:text)
    assert_empty nodes.css("em, strong")
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

  def test_indented_shell_code_stays_literal_while_following_math_is_rendered
    ["    ", "\t"].each do |indent|
      source = "Code example:\n\n#{indent}echo \"$HOME:$PATH\"\n\nThen $x^2$.\n"
      processor = MathPreprocessor::Processor.new(source)
      html = SiteBuilder.site.find_converter_instance(Jekyll::Converters::Markdown).convert(processor.process)
      document = Nokogiri::HTML.fragment(html)

      assert_equal code_text(source), document.at_css("code").text
      assert_equal ["x^2"], latex_of(processor)
      assert_equal 1, document.css(".math-expression-inline").size
    end
  end

  def test_indentation_in_paragraphs_and_lists_does_not_hide_math
    source = <<~TEXT
      A continued paragraph
          with $x^2$.

      - List item

          Prose $y^2$.

              echo "$HOME:$PATH"
    TEXT
    processor = MathPreprocessor::Processor.new(source)
    html = SiteBuilder.site.find_converter_instance(Jekyll::Converters::Markdown).convert(processor.process)
    document = Nokogiri::HTML.fragment(html)

    assert_equal %w[x^2 y^2], latex_of(processor)
    assert_equal code_text(source), document.at_css("li code").text
    assert_equal 2, document.css(".math-expression-inline").size
  end

  def test_longer_closing_fences_do_not_mask_following_math
    ["`", "~"].each do |marker|
      source = "#{marker * 4}bash\necho \"$HOME:$PATH\"\n#{marker * 5}\n\nThen $x^2$.\n"
      processor = MathPreprocessor::Processor.new(source)
      html = SiteBuilder.site.find_converter_instance(Jekyll::Converters::Markdown).convert(processor.process)
      document = Nokogiri::HTML.fragment(html)

      assert_equal code_text(source), document.at_css("code").text
      assert_equal ["x^2"], latex_of(processor)
      assert_equal 1, document.css("p > .math-expression-inline").size
    end
  end

  def test_shorter_and_different_fences_do_not_close_a_code_block
    source = "````text\n```\n~~~~\n$x^2$\n`````\n\nThen $y^2$.\n"
    processor = MathPreprocessor::Processor.new(source)
    result = processor.process

    assert_includes result, "```\n~~~~\n$x^2$\n`````"
    assert_equal ["y^2"], latex_of(processor)
  end

  def test_dollar_signs_in_highlight_blocks_stay_literal
    source = "{% highlight r %}\ndf$col + df$other\n{% endhighlight %}"
    assert_equal source, MathPreprocessor::Processor.new(source).process
  end

  def test_prices_stay_text
    source = "It costs $5 a month, or $50 a year."
    assert_equal source, MathPreprocessor::Processor.new(source).process
  end

  # MathJax and KaTeX render `$ … $` with spaces inside the dollars, which
  # Pandoc's rule leaves out, so a page whose only math was written that way
  # loaded neither engine.
  def test_padded_inline_math_with_tex_is_wrapped
    processor = MathPreprocessor::Processor.new('Precision is $ \frac{TP}{TP + FP} $ here.')
    result = processor.process

    assert_match(/math-expression-inline[^>]*>\$ \\frac\{TP\}\{TP \+ FP\} \$</, result)
    assert_equal ['\frac{TP}{TP + FP}'], latex_of(processor)
  end

  def test_padded_prices_stay_text
    source = "It costs $ 5 a month, or $ 50 a year."
    assert_equal source, MathPreprocessor::Processor.new(source).process
  end

  # Unless the wrapped expression is set aside, the padded pattern pairs the
  # dollar sign before 5 with the one inside the wrapper, whose attributes hold
  # a TeX command, and wraps the markup.
  def test_padded_pattern_leaves_wrapped_math_alone
    processor = MathPreprocessor::Processor.new('It costs $ 5, see $\alpha$.')
    result = processor.process

    assert result.start_with?("It costs $ 5, see <span "), result
    assert_equal ['\alpha'], latex_of(processor)
  end

  # A `mathjax: true` in front matter defaults used to win over a page's
  # `math: false`.
  def test_math_front_matter_wins_over_mathjax
    document = page_with("Costs $5 or $x$.", "mathjax" => true, "math" => false)
    MathPreprocessor.apply(document)
    assert_equal "Costs $5 or $x$.", document.content

    document = page_with("Costs $5 or $x$.", "mathjax" => false, "math" => true)
    MathPreprocessor.apply(document)
    assert_includes document.content, "math-expression-inline"
  end

  private

  def code_text(source)
    html = SiteBuilder.site.find_converter_instance(Jekyll::Converters::Markdown).convert(source)
    Nokogiri::HTML.fragment(html).at_css("code").text
  end

  def page_with(content, data)
    Struct.new(:content, :data, :output_ext).new(content, data, ".html")
  end

  def latex_of(processor)
    processor.expressions.map { |expression| expression["latex"] }
  end
end
