# frozen_string_literal: true

require_relative "test_helper"

# Theorems, definitions and the other statements, and proofs
# (_plugins/statements.rb). Articles wrote them as a blockquote with a bold
# "Theorem 1." typed by hand, which nothing numbered, linked or checked (#249).
class StatementsTest < Minitest::Test
  def statement(kind, id, body = "A statement.", attributes = "")
    "{% #{kind} id=\"#{id}\"#{attributes} %}\n#{body}\n{% end#{kind} %}\n"
  end

  def headings(doc)
    doc.css(".datalog-statement__heading").map { |heading| heading.text.strip }
  end

  def test_each_kind_is_numbered_on_its_own_and_can_be_referred_to
    doc = build(<<~MARKDOWN)
      By {% ref thm-b %}, {% ref lem-a %} and {% ref def-a %}.

      #{statement('theorem', 'thm-a')}
      #{statement('lemma', 'lem-a')}
      #{statement('theorem', 'thm-b')}
      #{statement('definition', 'def-a')}
    MARKDOWN

    assert_equal ["Theorem 1.", "Lemma 1.", "Theorem 2.", "Definition 1."], headings(doc)
    assert_equal({ "#thm-b" => "Theorem 2", "#lem-a" => "Lemma 1", "#def-a" => "Definition 1" },
                 doc.css("a.datalog-ref").to_h { |link| [link["href"], link.text] })
    doc.css(".datalog-statement").each do |group|
      assert_equal "group", group["role"]
      assert doc.at_css("##{group['aria-labelledby']}"), "#{group['id']} is labelled by its heading"
    end
  end

  def test_a_title_follows_the_number_and_is_escaped
    doc = build(statement("theorem", "thm-a", "Body.", ' title="Consistency <of> & more"'))
    html = doc.at_css(".datalog-statement__heading").inner_html

    assert_equal ["Theorem 1 (Consistency <of> & more)."], headings(doc)
    assert_includes html, "(Consistency &lt;of&gt; &amp; more)"
  end

  def test_a_label_replaces_the_number_and_does_not_count
    doc = build("See {% ref thm-main %}.\n\n#{statement('theorem', 'thm-main', 'Main.', ' label="A"')}" \
                "#{statement('theorem', 'thm-b')}")

    assert_equal ["Theorem A.", "Theorem 1."], headings(doc)
    assert_equal "Theorem A", doc.at_css("a.datalog-ref").text
  end

  def test_a_proof_names_its_statement_and_ends_with_a_mark
    proofs = ['{% proof for="thm-a" %}', "{% proof %}", '{% proof qed="false" %}'].map do |tag|
      "#{tag}\nIt follows.\n{% endproof %}\n"
    end
    proofs = build(statement("theorem", "thm-a") + proofs.join).css(".datalog-proof")

    headings = proofs.map { |proof| proof.at_css(".datalog-proof__heading").text }

    assert_equal ["Proof of Theorem 1.", "Proof.", "Proof."], headings
    assert_equal "#thm-a", proofs.first.at_css("a.datalog-ref")["href"]
    assert_equal([true, true, false], proofs.map { |proof| !proof.at_css(".datalog-proof__end").nil? })
    labels = proofs.map { |proof| proof["aria-labelledby"] }
    assert_equal labels.uniq, labels, "each proof is labelled by its own heading"
  end

  def test_bodies_keep_their_markdown_math_and_code
    body = "Let $\\theta_n \\to \\theta$.\n\nThen\n\n$$\nP(A) = 1\n$$\n\n```ruby\nx = 1\n\ny = 2\n```\n\n- a step"
    doc = build(statement("theorem", "thm-a", body))
    statement = doc.at_css(".datalog-statement__body")

    assert_equal 2, statement.css("> p").size
    assert_equal 2, statement.css('[role="math"]').size, "inline and display math go through the math preprocessor"
    assert_includes statement.at_css("pre").text, "x = 1\n\ny = 2"
    assert_equal "a step", statement.at_css("li").text
  end

  def test_a_duplicate_id_across_figures_and_statements_stops_the_build
    figure = "{% figure id=\"thm-a\" src=\"/a.png\" alt=\"A\" %}\nCaption.\n{% endfigure %}\n"
    error = assert_raises(Jekyll::Errors::FatalException) { build(statement("theorem", "thm-a") + figure) }

    assert_includes error.message, "two numbered figures, tables or statements with the id \"thm-a\""
  end

  def test_a_proof_of_a_missing_statement_stops_the_build
    error = assert_raises(Jekyll::Errors::FatalException) { build("{% proof for=\"thm-gone\" %}\nX.\n{% endproof %}") }

    assert_includes error.message, "refers to \"thm-gone\""
  end

  def test_labels_follow_the_page_language
    source = "#{statement('theorem', 'thm-a')}{% proof for=\"thm-a\" %}\nX.\n{% endproof %}"
    doc = build(source, front_matter: "lang: pt\n")

    assert_equal ["Teorema 1."], headings(doc)
    assert_equal "Demonstração de Teorema 1.", doc.at_css(".datalog-proof__heading").text
  end

  def test_a_label_must_be_simple
    error = assert_raises(StandardError) { build(statement("theorem", "thm-a", "X.", ' label="<b>"')) }

    assert_includes error.message, "takes a label of letters, digits"
  end

  def test_an_excerpt_reads_statement_numbers_from_the_post_source
    limits = "---\nlayout: null\n---\nBy {% ref thm-b %} and {% ref thm-main %}.\n\n" \
             "#{statement('theorem', 'thm-main', 'Main.', ' label="A"')}#{statement('theorem', 'thm-b')}"
    listing = build("{% for post in site.posts %}{{ post.excerpt }}{% endfor %}",
                    posts: { "2024-05-01-limits" => limits })

    assert_equal ["Theorem 1", "Theorem A"], listing.css("a.datalog-ref").map(&:text)
  end

  private

  # `posts` are whole files, front matter and all, for the tests about what a
  # post's excerpt carries into a listing.
  def build(body, front_matter: "", posts: {})
    TestSite.build(title: "Statements", kramdown: { "input" => "GFM" }) do |source|
      source.theme("_data/i18n")
      source.page("index.md", body, "layout: null\n#{front_matter}")
      posts.each { |name, contents| source.write("_posts/#{name}.md", contents) }
    end.html("index.html")
  end
end
