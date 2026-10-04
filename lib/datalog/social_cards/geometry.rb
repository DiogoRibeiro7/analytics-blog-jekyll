# frozen_string_literal: true

module Datalog
  module SocialCards
    # SVG's transforms as the six numbers of matrix(a b c d e f), which is
    # also the order of MVG's `affine`.
    module Geometry
      IDENTITY_MATRIX = [1.0, 0.0, 0.0, 1.0, 0.0, 0.0].freeze
      NUMBER = /-?(?:\d+\.?\d*|\.\d+)(?:e[-+]?\d+)?/i
      # The arguments hold no parenthesis, so a run of unclosed ones fails
      # at once rather than scanning to the end from each.
      TRANSFORM = /(matrix|translate|scale|rotate)\s*\(([^()]*)\)/

      module_function

      # A `transform` attribute's list of operations, as one matrix.
      def transform(value)
        matrix = IDENTITY_MATRIX
        value.to_s.scan(TRANSFORM) do |name, args|
          matrix = multiply(matrix, operation(name, args.scan(NUMBER).map(&:to_f)))
        end
        matrix
      end

      def operation(name, values)
        case name
        when "matrix" then values.size == 6 ? values : IDENTITY_MATRIX
        when "translate" then [1.0, 0.0, 0.0, 1.0, values[0].to_f, values[1].to_f]
        when "scale" then [values[0] || 1.0, 0.0, 0.0, values[1] || values[0] || 1.0, 0.0, 0.0]
        when "rotate" then rotation(*values)
        end
      end

      def rotation(degrees = 0.0, center_x = 0.0, center_y = 0.0)
        radians = degrees * Math::PI / 180
        cos = Math.cos(radians)
        sin = Math.sin(radians)
        turn = [cos, sin, -sin, cos, 0.0, 0.0]
        multiply(multiply([1.0, 0.0, 0.0, 1.0, center_x, center_y], turn), [1.0, 0.0, 0.0, 1.0, -center_x, -center_y])
      end

      # Two matrices composed: the result applies `inner` first.
      def multiply(outer, inner)
        a, b, c, d, e, f = outer
        g, h, i, j, k, l = inner
        [(a * g) + (c * h), (b * g) + (d * h), (a * i) + (c * j), (b * i) + (d * j),
         (a * k) + (c * l) + e, (b * k) + (d * l) + f]
      end
    end
  end
end
