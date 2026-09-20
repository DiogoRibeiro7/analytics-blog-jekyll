# frozen_string_literal: true

module Datalog
  # The slug `datalog new` gives a scaffolded post, notebook or project. It
  # names the file, and through the filename the page's URL, so it follows
  # Jekyll's own rule rather than a second one of its own.
  module Slug
    module_function

    # "Análise de Séries" becomes "analise-de-series". The ASCII-only
    # character class this replaced deleted every accented letter instead of
    # carrying it across, leaving "an-lise-de-s-ries".
    def of(text)
      require "jekyll"

      normalized = utf8(text)
      latin = Jekyll::Utils.slugify(normalized, mode: "latin").to_s
      # A title written in a script the transliteration table does not cover —
      # Greek, Cyrillic, Chinese — comes back empty. Keeping its own
      # characters beats naming the file after its date alone.
      latin.empty? ? Jekyll::Utils.slugify(normalized).to_s : latin
    end

    # What the console hands over is tagged with the console's encoding, which
    # on Windows is rarely UTF-8, and transliteration raises on a string whose
    # tag and bytes disagree. The bytes are usually UTF-8 already, so they are
    # re-tagged when that reads, and converted when it does not.
    def utf8(text)
      string = text.to_s
      return string if string.encoding == Encoding::UTF_8 && string.valid_encoding?

      retagged = string.dup.force_encoding(Encoding::UTF_8)
      return retagged if retagged.valid_encoding?

      string.encode(Encoding::UTF_8, invalid: :replace, undef: :replace, replace: "")
    end
  end
end
