module ActiveRecord
  module HierarchicalQuery
    module CTE
      class RecursiveTerm
        # @return [ActiveRecord::HierarchicalQuery::CTE::Query]
        attr_reader :builder

        delegate :query, to: :builder

        # @param [ActiveRecord::HierarchicalQuery::CTE::QueryBuilder] builder
        def initialize(builder)
          @builder = builder
        end

        def arel
          arel = scope.select(columns)
                      .arel
                      .join(query.recursive_table).on(query.join_conditions)

          builder.cycle_detector.apply_to_recursive(arel)
        end

        private
        def scope
          query.child_scope_value
        end

        def columns
          columns = builder.columns.to_a
          columns << ordering if query.orderings.any?
          columns
        end

        def ordering
          column_name = query.ordering_column_name
          left = query.recursive_table[column_name]
          right = query.orderings.row_number_expression

          Arel::Nodes::ArrayConcat.new(left, right)
        end
      end
    end
  end
end