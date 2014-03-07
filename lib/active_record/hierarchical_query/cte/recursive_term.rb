module ActiveRecord
  module HierarchicalQuery
    module CTE
      class RecursiveTerm
        # @return [ActiveRecord::HierarchicalQuery::CTE::Query]
        attr_reader :query

        delegate :orderings,
                 :recursive_table,
                 :join_conditions,
                 :to => :query

        # @param [ActiveRecord::HierarchicalQuery::CTE::Query] query
        def initialize(query)
          @query = query
        end

        def arel
          scope.
              select(query.columns).
              select(ordering_column).
              arel.
              join(recursive_table).on(join_conditions)
        end

        private
        def scope
          query.builder.child_scope_value
        end

        def ordering_column
          if orderings.any?
            Arel::Nodes::ArrayConcat.new(parent_ordering_column, orderings.row_number_expression)
          else
            []
          end
        end

        def parent_ordering_column
          recursive_table[orderings.column_name]
        end
      end
    end
  end
end