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
  end

  module Visitors
    class ToSql < ToSql.superclass
      private
      if Arel::VERSION < '6.0.0'
        def visit_Arel_Nodes_PostgresArray o, *a
          "ARRAY[#{visit o.values, *a}]"
        end

        def visit_Arel_Nodes_ArrayConcat o, *a
          "#{visit o.left, *a} || #{visit o.right, *a}"
        end
      else
        ARRAY_OPENING = 'ARRAY['.freeze
        ARRAY_CLOSING = ']'.freeze
        ARRAY_CONCAT = '||'.freeze

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
      end
    end
  end
end