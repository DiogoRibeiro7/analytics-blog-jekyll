# frozen_string_literal: true

require_relative "font"

module Datalog
  module SocialCards
    # Sets a card's text in the fonts the theme ships: wraps it to a width,
    # shrinks it until it fits its lines and height, and draws each line as a
    # path. A character neither font has is decomposed (ℝ reads R), spelled
    # out (∈ reads "in"), or left out; never drawn as a box.
    class Typesetter
      FONT_DIR = File.expand_path("fonts", __dir__)
      # The serif is the theme's heading face; the sans its text face.
      FONTS = { "serif" => "IBMPlexSerif-SemiBold.ttf", "sans" => "IBMPlexSans-Regular.ttf" }.freeze
      SPELLED = {
        "∈" => " in ", "∉" => " not in ", "∀" => "for all ", "∃" => "there is ", "∇" => "grad ",
        "∝" => " ~ ", "⋯" => "…", "‖" => "||", "∪" => " ∪ ", "∩" => " ∩ ", "⊂" => " ⊂ ", "⊆" => " ⊆ ",
        "∅" => "{}", "⟨" => "<", "⟩" => ">", "∘" => "o", "⇒" => "=>", "⇔" => "<=>", "∓" => "-+", "↦" => "->"
      }.freeze
      ELLIPSIS = "…"

      Line = Struct.new(:text, :width)
      # A text slot's room: its width and, when it has one, its height; the
      # size to start from and the smallest to go to; its lines; the line
      # height, as a share of the size.
      Box = Struct.new(:width, :height, :font_size, :min_font_size, :max_lines, :line_height, keyword_init: true) do
        def initialize(min_font_size: nil, max_lines: 1, line_height: 1.2, **rest)
          super
          self.min_font_size ||= font_size
        end
      end

      def self.fonts
        @fonts ||= FONTS.transform_values { |file| Font.new(File.join(FONT_DIR, file)) }
      end

      attr_reader :font

      def initialize(name)
        fonts = self.class.fonts
        @font = fonts.fetch(name) { fonts.fetch("sans") }
        @fallback = fonts.values.find { |other| !other.equal?(@font) }
        @resolved = {}
      end

      # Each character the text keeps, with the font that draws it.
      def runs(text)
        text.each_char.flat_map { |char| resolve(char) }
      end

      def width(text, size)
        runs(text).sum { |char, font| font.advance(font.glyph_id(char)) * size / font.units_per_em.to_f }
      end

      # The size it fits at and its lines, from `size` down to `min_size` in
      # steps of two pixels. Past the smallest size the last line ends in an
      # ellipsis.
      def fit(text, box)
        text = text.to_s.gsub(/\s+/, " ").strip
        return [box.font_size, []] if text.empty?

        sizes(box.font_size, box.min_font_size).each do |candidate|
          lines = wrap(text, box.width, candidate)
          return [candidate, lines] if fits?(lines.size, candidate, box)
        end
        smallest = box.min_font_size
        [smallest, truncate(wrap(text, box.width, smallest), lines_at(smallest, box), box.width, smallest)]
      end

      # Greedy, at spaces; a word wider than the line is cut where it must be.
      def wrap(text, max_width, size)
        lines = []
        current = nil
        text.split.each do |word|
          candidate = current ? "#{current} #{word}" : word
          if width(candidate, size) <= max_width
            current = candidate
            next
          end
          lines << current if current
          current = word
          while width(current, size) > max_width && current.length > 1
            cut = cut_point(current, max_width, size)
            lines << current[0...cut]
            current = current[cut..]
          end
        end
        lines << current if current
        lines.map { |line| Line.new(line, width(line, size)) }
      end

      # One path for a line, its baseline at `baseline`.
      def path(text, left, baseline, size)
        runs(text).map do |char, font|
          drawn = font.path(char, left, baseline, size)
          left += font.advance(font.glyph_id(char)) * size / font.units_per_em.to_f
          drawn
        end.reject(&:empty?).join(" ")
      end

      # The height of a capital, as a share of the size: where the first
      # baseline goes below the top of a text box.
      def cap_height
        @cap_height ||= begin
          tops = @font.outline(@font.glyph_id("H")).flatten(1).map { |point| point[1] }
          (tops.max || (@font.ascender * 0.7)) / @font.units_per_em.to_f
        end
      end

      private

      def resolve(char)
        @resolved[char] ||= if @font.glyph?(char) then [[char, @font]]
                            elsif @fallback&.glyph?(char) then [[char, @fallback]]
                            elsif SPELLED.key?(char) then SPELLED[char].each_char.flat_map do |spelled|
                              resolve(spelled)
                            end
                            else decomposed(char)
                            end
      end

      def decomposed(char)
        parts = char.unicode_normalize(:nfkd)
        return [] if parts == char

        parts.each_char.flat_map do |part|
          if @font.glyph?(part) then [[part, @font]]
          elsif @fallback&.glyph?(part) then [[part, @fallback]]
          else []
          end
        end
      end

      def sizes(size, min_size)
        found = []
        while size > min_size
          found << size
          size -= 2
        end
        found << min_size
      end

      def fits?(count, size, box)
        count <= lines_at(size, box)
      end

      # The lines the box holds at a size: its line count, and no more than
      # its height has room for.
      def lines_at(size, box)
        return box.max_lines unless box.height

        [box.max_lines, ((box.height + 0.01) / (size * box.line_height)).floor].min.clamp(1, nil)
      end

      def cut_point(word, max_width, size)
        cut = word.length - 1
        cut -= 1 while cut > 1 && width(word[0...cut], size) > max_width
        cut
      end

      def truncate(lines, allowed, max_width, size)
        return lines if lines.size <= allowed

        kept = lines.first(allowed)
        last = kept.last.text
        until last.length <= 1 || width("#{last}#{ELLIPSIS}", size) <= max_width
          shorter = last.sub(/\s*\S+\z/, "")
          last = shorter.empty? ? last[0...-1] : shorter
        end
        kept[-1] = Line.new("#{last}#{ELLIPSIS}", width("#{last}#{ELLIPSIS}", size))
        kept
      end
    end
  end
end
