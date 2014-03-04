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
    class ToSql < Arel::Visitors::Visitor
      private
      def visit_Arel_Nodes_PostgresArray o, *a
        "ARRAY[#{visit o.values, *a}]"
      end

      def visit_Arel_Nodes_ArrayConcat o, *a
        "#{visit o.left, *a} || #{visit o.right, *a}"
      end
    end
  end
end