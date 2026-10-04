# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/datalog/latex_speech"

# The build's reader of LaTeX, which names each expression for a screen reader
# (#417). The browser's reader (assets/js/math/latex-speech.js) checks the same
# cases in tests/js/latex-speech.test.js, so the build and the browser say the
# same thing about an expression.
class LatexSpeechTest < Minitest::Test
  CASES = JSON.parse(File.read(File.expand_path("fixtures/latex-speech.json", __dir__)))
              .select { |entry| entry.key?("latex") }

  def test_every_shared_case_reads_as_expected
    assert_operator CASES.size, :>=, 40, "expected the shared cases in tests/fixtures/latex-speech.json"
    CASES.each do |entry|
      assert_equal entry["label"], Datalog::LatexSpeech.speak(entry["latex"]), entry["latex"].inspect
    end
  end

  def test_no_label_keeps_a_backslash_a_label_key_or_an_environment_name
    CASES.each do |entry|
      label = Datalog::LatexSpeech.speak(entry["latex"])

      refute_match(/\\|eq:|\b(?:equation|align|pmatrix|array)\b/, label, entry["latex"].inspect)
    end
  end

  # Labels come from page content, so neither depth nor length may stall the
  # build: the tokenizer keeps a stack rather than recursing, and the reader
  # stops descending past a fixed depth.
  def test_deeply_nested_and_very_long_input_is_read_without_failing
    nested = "#{'{' * 5000}x#{'}' * 5000}"
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    Datalog::LatexSpeech.speak(nested)

    assert_match(/\Ax \+ alpha x/, Datalog::LatexSpeech.speak("x + \\alpha " * 20_000))
    assert_equal "", Datalog::LatexSpeech.speak("#{' ' * 50_000};")
    assert_operator Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, :<, 5
  end
end
