# frozen_string_literal: true

require "fastimage"
require "nokogiri"
require_relative "geometry"
require_relative "typesetter"

module Datalog
  module SocialCards
    # A card's SVG template, drawn as MVG, ImageMagick's own vector format.
    # Every ImageMagick reads MVG; SVG it reads only with a renderer that a
    # minimal install leaves out (Ubuntu's `imagemagick` without its
    # recommended packages reads no SVG at all). So the template is SVG, to
    # write and preview in anything, and this draws the part of SVG a card
    # needs:
    #
    #   rect, circle, ellipse, line, polyline, polygon, path, image and g;
    #   fill, stroke, stroke-width, opacity, fill-opacity, stroke-opacity,
    #   stroke-linecap, stroke-linejoin and fill-rule, as attributes or in
    #   `style`; transform (translate, scale, rotate, matrix).
    #
    # Gradients, filters, masks, `use` and plain <text> are not drawn. Text
    # goes in slots, each a <text> with `data-field` and no content, which
    # are set in the theme's fonts and drawn as outlines:
    #
    #   <text data-field="title" x="80" y="220" width="1040" height="280"
    #         font-size="68" data-min-font-size="40" data-max-lines="4"
    #         data-font="serif" data-line-height="1.15" fill="{{ink}}"/>
    #
    # `y` is the top of the box, not a baseline. A <rect data-field="logo">
    # is where the logo goes. {{background}}, {{ink}}, {{muted}} and
    # {{accent}} are the scheme's colours.
    class Template
      include Geometry

      class Error < StandardError; end

      WIDTH = 1200
      HEIGHT = 630
      DEFAULT = File.expand_path("template.svg", __dir__)
      FIELDS = %w[site kicker title byline detail].freeze
      DRAWN = %w[rect circle ellipse line polyline polygon path image].freeze
      SKIPPED = %w[title desc metadata defs style].freeze
      STYLE = %w[fill stroke stroke-width opacity fill-opacity stroke-opacity stroke-linecap stroke-linejoin
                 fill-rule].freeze
      COLOR = /\A(?:#\h{3,8}|[a-z]+|rgba?\(\s*[\d.]+%?(?:\s*,\s*[\d.]+%?){2,3}\s*\))\z/i
      PATH_DATA = /\A[MmLlHhVvCcSsQqTtAaZz0-9eE.,+\-\s]*\z/

      # SVG's initial values: what an element with no style of its own, or of
      # the <svg> around it, is drawn with.
      BASE_STYLE = { "fill" => "black", "opacity" => 1.0 }.freeze

      attr_reader :ignored

      # `source` is the SVG text; `resolve` turns an image's href into a file.
      def initialize(source, colors:, resolve: ->(_href) {})
        filled = source.to_s.gsub(/\{\{\s*(\w+)\s*\}\}/) { colors.fetch(Regexp.last_match(1), Regexp.last_match(0)) }
        @document = Nokogiri::XML(filled, &:strict)
        @colors = colors
        @resolve = resolve
        @ignored = []
      rescue Nokogiri::XML::SyntaxError => e
        raise Error, "the card template is not well-formed SVG (#{e.message.strip})"
      end

      # The card as MVG. `fields` maps a slot's name to its text; `logo` is
      # nil, an SVG string, or the path of an image file.
      def to_mvg(fields, logo: nil)
        root = @document.root
        raise Error, "the card template's root element is not <svg>" unless root&.name == "svg"

        @fields = fields
        @logo = logo
        @out = ["viewbox 0 0 #{WIDTH} #{HEIGHT}"]
        walk(root, root_matrix(root), inherit(BASE_STYLE, root))
        @out.join("\n") << "\n"
      end

      # This SVG drawn into a box of the card, as MVG lines: a logo.
      def fitted(matrix, width, height)
        @fields = {}
        @logo = nil
        @out = []
        walk(@document.root, multiply(matrix, fitted_matrix(width, height)), inherit(BASE_STYLE, @document.root))
        @out
      end

      private

      def root_matrix(root)
        view = root["viewBox"].to_s.scan(NUMBER).map(&:to_f)
        view = [0.0, 0.0, length(root["width"], WIDTH), length(root["height"], HEIGHT)] unless view.size == 4
        sx = WIDTH / view[2]
        sy = HEIGHT / view[3]
        [sx, 0.0, 0.0, sy, -view[0] * sx, -view[1] * sy]
      end

      def walk(node, matrix, style)
        node.element_children.each do |child|
          next if SKIPPED.include?(child.name)

          own = multiply(matrix, transform(child["transform"]))
          inherited = inherit(style, child)
          case child.name
          when "g", "svg", "a" then walk(child, own, inherited)
          when "text" then slot(child, own, inherited)
          when *DRAWN then draw(child, own, inherited)
          else @ignored << child.name
          end
        end
      end

      def inherit(style, node)
        own = STYLE.to_h { |name| [name, node[name]] }.compact
        node["style"].to_s.split(";").each do |declaration|
          name, value = declaration.split(":", 2).map(&:strip)
          own[name] = value if STYLE.include?(name) && value
        end
        merged = style.merge(own)
        merged["opacity"] = style.fetch("opacity", 1.0) * number(own["opacity"], 1.0)
        merged
      end

      def draw(node, matrix, style)
        return logo(node, matrix) if node["data-field"] == "logo"

        primitive = primitive(node)
        emit(matrix, style, primitive) if primitive
      end

      def primitive(node)
        n = ->(name, fallback = 0) { number(node[name], fallback) }
        case node.name
        when "rect" then rectangle(box(node), n["rx", n["ry"]], n["ry", n["rx"]])
        when "circle" then "circle #{pair(n['cx'], n['cy'])} #{pair(n['cx'], n['cy'] + n['r'])}"
        when "ellipse" then "ellipse #{pair(n['cx'], n['cy'])} #{pair(n['rx'], n['ry'])} 0,360"
        when "line" then "line #{pair(n['x1'], n['y1'])} #{pair(n['x2'], n['y2'])}"
        when "polyline", "polygon" then points(node)
        when "path" then path_data(node["d"])
        when "image" then image(node)
        end
      end

      def rectangle(box, radius_x, radius_y)
        left, top, width, height = box
        return if width <= 0 || height <= 0

        corners = "#{pair(left, top)} #{pair(left + width, top + height)}"
        return "rectangle #{corners}" unless radius_x.positive? || radius_y.positive?

        "roundrectangle #{corners} #{pair(radius_x, radius_y)}"
      end

      # [x, y, width, height] of an element.
      def box(node)
        %w[x y width height].map { |name| number(node[name]) }
      end

      def points(node)
        values = node["points"].to_s.scan(NUMBER).map(&:to_f)
        return if values.size < 4

        "#{node.name} #{values.each_slice(2).map { |x, y| pair(x, y.to_f) }.join(' ')}"
      end

      def path_data(data)
        data = data.to_s.strip
        return if data.empty?
        unless data.match?(PATH_DATA)
          raise Error, "a path in the card template has data that is not path data: #{data[0, 40]}"
        end

        "path '#{data}'"
      end

      def image(node)
        href = node["href"] || node["xlink:href"]
        file = @resolve.call(href)
        unless file
          @ignored << "image #{href}"
          return
        end
        raise Error, "the image #{file} has a quote in its path" if file.include?("'")

        size = pair(number(node["width"]), number(node["height"]))
        "image over #{pair(number(node['x']), number(node['y']))} #{size} '#{file}'"
      end

      def emit(matrix, style, *primitives)
        @out << "push graphic-context"
        @out << "affine #{matrix.map { |value| format_number(value) }.join(',')}"
        @out.concat(style_commands(style))
        @out.concat(primitives)
        @out << "pop graphic-context"
      end

      # An opacity is written only for a colour that is painted, and only
      # below 1: ImageMagick 7 reads `stroke-opacity 1` after `stroke none` as
      # an opaque black stroke, which thinned every light glyph on a dark card.
      def style_commands(style)
        opacity = style.fetch("opacity", 1.0)
        fill = paint(style["fill"] || "black")
        stroke = paint(style["stroke"] || "none")
        commands = ["fill #{fill}", "stroke #{stroke}"]
        fill_opacity = opacity * number(style["fill-opacity"], 1.0)
        commands << "fill-opacity #{format_number(fill_opacity)}" if fill != "none" && fill_opacity < 1
        commands.concat(stroke_commands(style, opacity)) unless stroke == "none"
        commands << "fill-rule #{style['fill-rule'] == 'evenodd' ? 'evenodd' : 'nonzero'}"
        commands
      end

      def stroke_commands(style, opacity)
        commands = ["stroke-width #{format_number(number(style['stroke-width'], 1.0))}"]
        stroke_opacity = opacity * number(style["stroke-opacity"], 1.0)
        commands << "stroke-opacity #{format_number(stroke_opacity)}" if stroke_opacity < 1
        cap = style["stroke-linecap"]
        join = style["stroke-linejoin"]
        commands << "stroke-linecap #{cap}" if %w[butt round square].include?(cap)
        commands << "stroke-linejoin #{join}" if %w[miter round bevel].include?(join)
        commands
      end

      def paint(value)
        value = value.to_s.strip
        value = @colors.fetch("accent", "black") if value.casecmp?("currentColor")
        return "none" if value.casecmp?("none") || value.empty?
        raise Error, "#{value.inspect} in the card template is not a colour" unless value.match?(COLOR)

        "'#{value}'"
      end

      # A text slot, set and drawn as one path per line.
      def slot(node, matrix, style)
        name = node["data-field"].to_s
        unless FIELDS.include?(name)
          @ignored << "text #{name.empty? ? 'without data-field' : name}"
          return
        end

        text = @fields[name].to_s.strip
        return if text.empty?

        setter = Typesetter.new(node["data-font"] || "sans")
        text_box = text_box(node)
        size, lines = setter.fit(text, text_box)
        left = number(node["x"])
        top = number(node["y"]) + (setter.cap_height * size)
        paths = lines.each_with_index.map do |line, index|
          data = setter.path(line.text, left, top + (index * size * text_box.line_height), size)
          "path '#{data}'" unless data.empty?
        end.compact
        emit(matrix, style.merge("stroke" => "none"), *paths) unless paths.empty?
      end

      def text_box(node)
        size = number(node["font-size"], 32)
        height = node["height"] || node["data-height"]
        Typesetter::Box.new(width: number(node["width"] || node["data-width"], WIDTH),
                            height: height && number(height), font_size: size,
                            min_font_size: number(node["data-min-font-size"], size),
                            max_lines: number(node["data-max-lines"], 1).to_i,
                            line_height: number(node["data-line-height"], 1.2))
      end

      # The logo, fitted in the slot's box and centred in it: an SVG drawn
      # with the rest of the card, or an image laid over it.
      def logo(node, matrix)
        return if @logo.nil?

        left, top, width, height = box(node)
        if @logo.lstrip.start_with?("<")
          svg = Template.new(@logo, colors: @colors, resolve: @resolve)
          @out.concat(svg.fitted(multiply(matrix, [1.0, 0.0, 0.0, 1.0, left, top]), width, height))
          @ignored.concat(svg.ignored)
        else
          image_logo(@logo, matrix, box(node))
        end
      end

      def image_logo(file, matrix, box)
        raise Error, "the logo #{file} has a quote in its path" if file.include?("'")

        left, top, width, height = box
        natural = FastImage.size(file) || [width, height]
        scale = [width / natural[0].to_f, height / natural[1].to_f].min
        drawn = [natural[0] * scale, natural[1] * scale]
        corner = pair(left + ((width - drawn[0]) / 2), top + ((height - drawn[1]) / 2))
        emit(matrix, {}, "image over #{corner} #{pair(*drawn)} '#{file}'")
      end

      # Scales this SVG's view box into a width and height, keeping its shape.
      def fitted_matrix(width, height)
        root = @document.root
        view = root["viewBox"].to_s.scan(NUMBER).map(&:to_f)
        view = [0.0, 0.0, length(root["width"], width), length(root["height"], height)] unless view.size == 4
        scale = [width / view[2], height / view[3]].min
        dx = ((width - (view[2] * scale)) / 2) - (view[0] * scale)
        dy = ((height - (view[3] * scale)) / 2) - (view[1] * scale)
        [scale, 0.0, 0.0, scale, dx, dy]
      end

      def length(value, fallback)
        found = value.to_s[NUMBER]
        found ? found.to_f : fallback.to_f
      end

      def number(value, fallback = 0)
        found = value.to_s[/\A\s*#{NUMBER}/o]
        found ? found.to_f : fallback.to_f
      end

      def pair(first, second)
        "#{format_number(first)},#{format_number(second)}"
      end

      def format_number(value)
        rounded = value.to_f.round(3)
        rounded == rounded.to_i ? rounded.to_i.to_s : rounded.to_s
      end
    end
  end
end
