# coding: utf-8

require 'active_record/hierarchical_query/cte/columns'
require 'active_record/hierarchical_query/cte/cycle_detector'
require 'active_record/hierarchical_query/cte/union_term'
require 'active_record/hierarchical_query/cte/orderings'

module ActiveRecord
  module HierarchicalQuery
    module CTE
      # CTE query builder
      class QueryBuilder
        attr_reader :query,
                    :columns,
                    :orderings,
                    :cycle_detector

        delegate :klass, :table, :recursive_table, :to => :query

        # @param [ActiveRecord::HierarchicalQuery::Query] query
        def initialize(query)
          @query = query
          @columns = Columns.new(self)
          @orderings = Orderings.new(self)
          @cycle_detector = CycleDetector.new(self)
        end

        # @return [Arel::SelectManager]
        def arel
          Arel::SelectManager.new(table.engine).
              with(:recursive, with_query).
              from(recursive_table).
              project(recursive_table[Arel.star]).
              take(query.limit_value).
              skip(query.offset_value).
              order(*orderings.cte_orderings)
        end

        def join_conditions
          query.connect_by_value[recursive_table, table]
        end

        private
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
          UnionTerm.new(self)
        end
      end
    end
  end
end