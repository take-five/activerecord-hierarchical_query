require 'arel/visitors/to_sql'

module Arel
  module Nodes
    class PostgresArray < Node
      include AliasPredication
      attr_accessor :values

      def initialize(values)
        self.values = values
      end
    end

    class ArrayConcat < Binary
    end

    class UnionDistinct < Binary
    end
  end

  module Visitors
    class ToSql < ToSql.superclass
      private
      ARRAY_OPENING = 'ARRAY['.freeze
      ARRAY_CLOSING = ']'.freeze
      ARRAY_CONCAT = '||'.freeze

      if Gem::Version.new(Arel::VERSION) < Gem::Version.new('6.0.0')
        def visit_Arel_Nodes_PostgresArray o, *a
          "#{ARRAY_OPENING}#{visit o.values, *a}#{ARRAY_CLOSING}"
        end

        def visit_Arel_Nodes_ArrayConcat o, *a
          "#{visit o.left, *a} #{ARRAY_CONCAT} #{visit o.right, *a}"
        end

        def visit_Arel_Nodes_UnionDistinct o, *a
          "( #{visit o.left, *a} UNION DISTINCT #{visit o.right, *a} )"
        end
      else
        def visit_Arel_Nodes_PostgresArray o, collector
          collector << ARRAY_OPENING
          visit o.values, collector
          collector << ARRAY_CLOSING
        end

        def visit_Arel_Nodes_ArrayConcat o, collector
          visit o.left, collector
          collector << ARRAY_CONCAT
          visit o.right, collector
        end

        def visit_Arel_Nodes_UnionDistinct o, collector
          collector << "( "
          infix_value(o, collector, " UNION DISTINCT ") << " )"
        end
      end
    end
  end
end
