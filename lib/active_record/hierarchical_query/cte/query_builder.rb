# coding: utf-8

require 'active_record/hierarchical_query/cte/columns'
require 'active_record/hierarchical_query/cte/cycle_detector'
require 'active_record/hierarchical_query/cte/union_term'

module ActiveRecord
  module HierarchicalQuery
    module CTE
      # CTE query builder
      class QueryBuilder
        attr_reader :query,
                    :columns,
                    :cycle_detector,
                    :options

        delegate :klass, :table, :recursive_table, to: :query

        # @param [ActiveRecord::HierarchicalQuery::Query] query
        def initialize(query, options: {})
          @query = query
          @columns = Columns.new(@query)
          @cycle_detector = CycleDetector.new(@query)
          @options = options
        end

        def bind_values
          union_term.bind_values
        end

        # @return [Arel::SelectManager]
        def build_arel
          build_manager
          build_select
          build_limits
          build_order

          @arel
        end

        private
        def build_manager
          @arel = Arel::SelectManager.new(table.engine).
              with(:recursive, with_query).
              from(recursive_table)
        end

        # "categories__recursive" AS (
        #   SELECT ... FROM "categories"
        #   UNION ALL
        #   SELECT ... FROM "categories"
        #   INNER JOIN "categories__recursive" ON ...
        # )
        def with_query
          Arel::Nodes::As.new(recursive_table, union_term.arel)
        end

        def union_term
          @union_term ||= UnionTerm.new(self, @options)
        end

        def build_select
          if @query.distinct_value
            @arel.project(recursive_table[Arel.star]).distinct
          else
            @arel.project(recursive_table[Arel.star])
          end
        end

        def build_limits
          @arel.take(query.limit_value).skip(query.offset_value)
        end

        def build_order
          @arel.order(order_column.asc) if should_order?
        end

        def should_order?
          query.orderings.any? && (query.limit_value || query.offset_value)
        end

        def order_column
          recursive_table[query.ordering_column_name]
        end
      end
    end
  end
end
