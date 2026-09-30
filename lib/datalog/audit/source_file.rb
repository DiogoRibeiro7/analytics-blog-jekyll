# frozen_string_literal: true

require "date"
require "yaml"

module Datalog
  class Audit
    # One content file as its author wrote it: the front matter keys with the
    # line each is on, and the body with its code set aside, line by line, so
    # a finding names the line the author would edit.
    class SourceFile
      # Code shows what it shows: nothing inside it is a statement, a figure
      # reference, a link or an image. Each match is blanked character for
      # character, newlines kept, so line numbers do not move.
      CODE = [
        /^[ \t]*(`{3,}|~{3,})[^\n]*\n.*?(?:^[ \t]*\1[ \t]*$|\z)/m,
        /\{%-?\s*(highlight|raw)\b.*?\{%-?\s*end\1\s*-?%\}/m,
        %r{<(pre|code)\b[^>]*>.*?</\1>}mi,
        /`[^`\n]+`/,
        /<!--.*?-->/m,
        /\{%-?\s*comment\s*-?%\}.*?\{%-?\s*endcomment\s*-?%\}/m
      ].freeze

      attr_reader :path, :relative, :front_matter, :key_lines, :body_start, :body, :lines

      def initialize(path, relative)
        @path = path
        @relative = relative
        text = File.read(path, encoding: "bom|utf-8")
        @front_matter, @key_lines, @body_start, @body = split(text)
        @lines = mask(@body).split("\n", -1)
      end

      # The body's lines with code blanked, each with its line in the file.
      def each_line
        return enum_for(:each_line) unless block_given?

        @lines.each_with_index { |line, index| yield line, @body_start + index }
      end

      # The line in the file of the body's `offset`th character.
      def line_at(offset)
        @body_start + masked_body[0, offset].count("\n")
      end

      def masked_body
        @masked_body ||= @lines.join("\n")
      end

      def key_line(key)
        @key_lines.fetch(key, 1)
      end

      def post?
        relative.match?(%r{(\A|/)_posts/})
      end

      private

      def split(text)
        match = text.match(/\A---[ \t]*\r?\n(.*?)^---[ \t]*\r?$\n?/m)
        return [{}, {}, 1, text] unless match

        yaml = match[1]
        data = begin
          YAML.safe_load(yaml, permitted_classes: [Date, Time], aliases: true)
        rescue Psych::Exception
          nil
        end
        key_lines = {}
        yaml.each_line.with_index(2) do |line, number|
          key = line[/\A([A-Za-z_][\w-]*)\s*:/, 1]
          key_lines[key] ||= number if key
        end
        [data.is_a?(Hash) ? data : {}, key_lines, match[0].count("\n") + 1, match.post_match]
      end

      def mask(text)
        CODE.reduce(text) do |masked, pattern|
          masked.gsub(pattern) { |code| code.gsub(/[^\n]/, " ") }
        end
      end
    end
  end
end
