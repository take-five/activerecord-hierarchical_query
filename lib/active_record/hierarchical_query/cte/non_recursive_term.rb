# coding: utf-8

module ActiveRecord
  module HierarchicalQuery
    module CTE
      class NonRecursiveTerm
        DISALLOWED_CLAUSES = :order, :limit, :offset, :group, :having

        attr_reader :builder
        delegate :query, to: :builder

        # @param [ActiveRecord::HierarchicalQuery::CTE::QueryBuilder] builder
        def initialize(builder)
          @builder = builder
        end

        def bind_values
          scope.bind_values
        end

        def arel
          arel = scope.arel

          builder.cycle_detector.apply_to_non_recursive(arel)
        end

        private
        def scope
          @scope ||= query.
              start_with_value.
              select(columns).
              except(*DISALLOWED_CLAUSES).
              reorder(nil)
        end

        def columns
          columns = builder.columns.to_a

          if query.orderings.any?
            columns << ordering
          end

          columns
        end

        def ordering
          value = query.orderings.row_number_expression
          column_name = query.ordering_column_name

          Arel::Nodes::PostgresArray.new([value]).as(column_name)
        end
      end # class NonRecursiveTerm
    end
  end
end
