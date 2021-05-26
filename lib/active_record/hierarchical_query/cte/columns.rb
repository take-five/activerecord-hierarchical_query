module ActiveRecord
  module HierarchicalQuery
    module CTE
      class Columns
        # @param [ActiveRecord::HierarchicalQuery::Query] query
        def initialize(query)
          @query = query
        end

        # returns columns to be selected from both recursive and non-recursive terms
        def to_a
          column_names = [@query.klass.primary_key] | connect_by_columns
          column_names.map { |name| @query.table[name] }
        end
        alias_method :to_ary, :to_a

        private
        def connect_by_columns
          columns = []
          traverse(@query.join_conditions) do |node|
            columns << node.name.to_s if node.is_a?(Arel::Attributes::Attribute)
          end
          columns
        end

        def traverse(ast, &blck)
          if ast && ast.respond_to?(:left) && ast.left
            traverse(ast.left, &blck)
          end

          if ast && ast.respond_to?(:right) && ast.right
            traverse(ast.right, &blck)
          end

          yield ast
        end
      end
    end
  end
end