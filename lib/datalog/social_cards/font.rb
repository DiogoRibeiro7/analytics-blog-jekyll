# frozen_string_literal: true

require_relative "outline"

module Datalog
  module SocialCards
    # A TrueType font, read with nothing but Ruby: the advance width of each
    # glyph, to wrap a title, and its outline, to draw it. A card's text is
    # drawn as paths, so neither ImageMagick nor the build machine needs the
    # font installed, and no font lookup can pick a different one.
    #
    # Reads the tables a static TrueType font always has (head, hhea, maxp,
    # hmtx, cmap, loca, glyf), simple and composite glyphs alike. Kerning and
    # ligatures are left out: the text is set from advance widths alone.
    class Font
      class Error < StandardError; end

      # Glyph flags, from the glyf table.
      ON_CURVE = 0x01
      X_SHORT = 0x02
      Y_SHORT = 0x04
      REPEAT = 0x08
      X_SAME = 0x10
      Y_SAME = 0x20

      # Component flags of a composite glyph.
      WORDS = 0x0001
      XY_VALUES = 0x0002
      SCALE = 0x0008
      MORE = 0x0020
      XY_SCALE = 0x0040
      TWO_BY_TWO = 0x0080

      IDENTITY = [1.0, 0.0, 0.0, 1.0].freeze

      attr_reader :file, :units_per_em, :ascender, :descender

      def initialize(file)
        @file = file
        @data = File.binread(file)
        @tables = directory
        read_head
        read_hhea
        @glyph_count = u16(table("maxp") + 4)
        @advances = Array.new(@metric_count) { |index| u16(table("hmtx") + (index * 4)) }
        @cmap = read_cmap
        @loca = read_loca
        @outlines = {}
      rescue ArgumentError, TypeError, NoMethodError => e
        raise Error, "#{file} is not a TrueType font this can read (#{e.message})"
      end

      # The glyph for a character, or 0 (.notdef) when the font has none.
      def glyph_id(char)
        @cmap.fetch(char.ord, 0)
      end

      def glyph?(char)
        !glyph_id(char).zero?
      end

      def advance(glyph)
        @advances.fetch(glyph) { @advances.last }
      end

      # The width of the text at a font size, in pixels.
      def width(text, size)
        text.each_char.sum { |char| advance(glyph_id(char)) } * size / units_per_em.to_f
      end

      # The text's outline as path data, from `left` along a baseline at a
      # size, in SVG's path syntax, which ImageMagick's MVG shares. The y
      # axis points down, as it does on the card.
      def path(text, left, baseline, size)
        scale = size / units_per_em.to_f
        commands = []
        text.each_char do |char|
          glyph = glyph_id(char)
          outline(glyph).each { |contour| commands << Outline.path(contour, left, baseline, scale) }
          left += advance(glyph) * scale
        end
        commands.join(" ")
      end

      # Contours of [x, y, on_curve] points in font units, y up.
      def outline(glyph, depth = 0)
        @outlines[glyph] ||= begin
          offset = @loca[glyph]
          length = @loca[glyph + 1].to_i - offset.to_i
          if offset.nil? || length <= 0 || depth > 8
            []
          else
            start = table("glyf") + offset
            contours = s16(start)
            contours.negative? ? composite(start + 10, depth) : simple(start + 10, contours)
          end
        end
      end

      private

      def directory
        (0...u16(4)).to_h do |index|
          record = 12 + (index * 16)
          [@data.byteslice(record, 4), u32(record + 8)]
        end
      end

      def table(tag)
        @tables.fetch(tag) { raise Error, "#{file} has no #{tag} table" }
      end

      def read_head
        head = table("head")
        @units_per_em = u16(head + 18)
        @long_offsets = s16(head + 50) == 1
      end

      def read_hhea
        hhea = table("hhea")
        @ascender = s16(hhea + 4)
        @descender = s16(hhea + 6)
        @metric_count = u16(hhea + 34)
      end

      # Unicode to glyph, from the format 12 subtable when there is one (all of
      # Unicode), else format 4 (the Basic Multilingual Plane).
      def read_cmap
        cmap = table("cmap")
        offsets = Array.new(u16(cmap + 2)) { |index| cmap + 4 + (index * 8) }.filter_map do |record|
          platform = u16(record)
          encoding = u16(record + 2)
          cmap + u32(record + 4) if platform.zero? || (platform == 3 && [1, 10].include?(encoding))
        end
        full = offsets.find { |offset| u16(offset) == 12 }
        return format12(full) if full

        bmp = offsets.find { |offset| u16(offset) == 4 }
        raise Error, "#{file} has no Unicode character map" unless bmp

        format4(bmp)
      end

      def format12(offset)
        Array.new(u32(offset + 12)) { |index| offset + 16 + (index * 12) }.each_with_object({}) do |group, map|
          first = u32(group)
          glyph = u32(group + 8)
          (first..u32(group + 4)).each { |code| map[code] = glyph + code - first }
        end
      end

      def format4(offset)
        segments = u16(offset + 6) / 2
        ends = offset + 14
        starts = ends + (segments * 2) + 2
        (0...segments).each_with_object({}) do |index, map|
          first = u16(starts + (index * 2))
          next if first == 0xFFFF

          (first..u16(ends + (index * 2))).each do |code|
            glyph = segment_glyph(starts + (segments * 2), segments, index, code, first)
            map[code] = glyph unless glyph.zero?
          end
        end
      end

      # A code's glyph in a format 4 segment: its delta alone, or the delta
      # added to an entry of the glyph array its range offset points into.
      def segment_glyph(deltas, segments, index, code, first)
        delta = s16(deltas + (index * 2))
        range_at = deltas + (segments * 2) + (index * 2)
        range = u16(range_at)
        return (code + delta) & 0xFFFF if range.zero?

        found = u16(range_at + range + ((code - first) * 2))
        found.zero? ? 0 : (found + delta) & 0xFFFF
      end

      def read_loca
        loca = table("loca")
        Array.new(@glyph_count + 1) do |index|
          @long_offsets ? u32(loca + (index * 4)) : u16(loca + (index * 2)) * 2
        end
      end

      def simple(at, count)
        ends = Array.new(count) { |index| u16(at + (index * 2)) }
        at += (count * 2)
        at += 2 + u16(at)
        flags, at = read_flags(at, ends.empty? ? 0 : ends.last + 1)
        xs, at = coordinates(flags, at, X_SHORT, X_SAME)
        ys, = coordinates(flags, at, Y_SHORT, Y_SAME)
        points = flags.each_with_index.map { |flag, index| [xs[index], ys[index], flag.anybits?(ON_CURVE)] }
        starts = [0] + ends[0...-1].map(&:succ)
        starts.zip(ends).map { |first, last| points[first..last] }
      end

      def read_flags(at, total)
        flags = []
        while flags.size < total
          flag = @data.getbyte(at)
          at += 1
          flags << flag
          next unless flag.anybits?(REPEAT)

          @data.getbyte(at).times { flags << flag }
          at += 1
        end
        [flags, at]
      end

      def coordinates(flags, at, short, same)
        value = 0
        values = flags.map do |flag|
          if flag.anybits?(short)
            step = @data.getbyte(at)
            at += 1
            value += flag.anybits?(same) ? step : -step
          elsif flag.nobits?(same)
            value += s16(at)
            at += 2
          end
          value
        end
        [values, at]
      end

      # A glyph made of others, each placed by an offset and an optional
      # scale or 2x2 transform: most accented letters.
      def composite(at, depth)
        contours = []
        loop do
          flags = u16(at)
          component = u16(at + 2)
          dx, dy, at = component_offset(flags, at + 4)
          (a, b, c, d), at = component_transform(flags, at)
          outline(component, depth + 1).each do |contour|
            contours << contour.map { |x, y, on| [(a * x) + (c * y) + dx, (b * x) + (d * y) + dy, on] }
          end
          break unless flags.anybits?(MORE)
        end
        contours
      end

      def component_offset(flags, at)
        if flags.anybits?(WORDS)
          dx = s16(at)
          dy = s16(at + 2)
          at += 4
        else
          dx, dy = @data.byteslice(at, 2).unpack("cc")
          at += 2
        end
        flags.anybits?(XY_VALUES) ? [dx, dy, at] : [0, 0, at]
      end

      def component_transform(flags, at)
        if flags.anybits?(SCALE)
          [[f2dot14(at), 0.0, 0.0, f2dot14(at)], at + 2]
        elsif flags.anybits?(XY_SCALE)
          [[f2dot14(at), 0.0, 0.0, f2dot14(at + 2)], at + 4]
        elsif flags.anybits?(TWO_BY_TWO)
          [[f2dot14(at), f2dot14(at + 2), f2dot14(at + 4), f2dot14(at + 6)], at + 8]
        else
          [IDENTITY, at]
        end
      end

      def f2dot14(at)
        s16(at) / 16_384.0
      end

      def u16(at)
        @data.byteslice(at, 2).unpack1("n")
      end

      def s16(at)
        @data.byteslice(at, 2).unpack1("s>")
      end

      def u32(at)
        @data.byteslice(at, 4).unpack1("N")
      end
    end
  end
end
