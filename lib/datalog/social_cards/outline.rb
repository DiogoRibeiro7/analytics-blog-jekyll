# frozen_string_literal: true

module Datalog
  module SocialCards
    # A TrueType contour as path commands. TrueType draws with quadratic
    # curves, and two off-curve points in a row imply an on-curve point
    # halfway between them.
    module Outline
      module_function

      # The contour's [x, y, on_curve] points, in font units with y up,
      # placed at `left` on a baseline and scaled: one closed subpath.
      def path(points, left, baseline, scale)
        return "" if points.empty?

        start, rest = start_and_rest(points)
        place = ->(point) { "#{number(left + (point[0] * scale))} #{number(baseline - (point[1] * scale))}" }
        commands = ["M #{place.call(start)}"]
        control = nil
        (rest + [start]).each do |point|
          commands << segment(point, control, place)
          control = point[2] ? nil : point
        end
        commands.compact.push("Z").join(" ")
      end

      # Where the subpath starts: the first on-curve point, or, when every
      # point is off the curve, halfway between the last and the first.
      def start_and_rest(points)
        on = points.index { |point| point[2] }
        return [points[on], points.rotate(on).drop(1)] if on

        first = points.first
        last = points.last
        [[(first[0] + last[0]) / 2.0, (first[1] + last[1]) / 2.0, true], points]
      end

      # The command that reaches `point`, given the pending control point.
      def segment(point, control, place)
        if point[2]
          control ? "Q #{place.call(control)} #{place.call(point)}" : "L #{place.call(point)}"
        elsif control
          middle = [(control[0] + point[0]) / 2.0, (control[1] + point[1]) / 2.0]
          "Q #{place.call(control)} #{place.call(middle)}"
        end
      end

      def number(value)
        rounded = value.round(2)
        rounded == rounded.to_i ? rounded.to_i.to_s : rounded.to_s
      end
    end
  end
end
