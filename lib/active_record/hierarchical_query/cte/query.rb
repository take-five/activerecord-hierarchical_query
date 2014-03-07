# coding: utf-8

require 'active_record/hierarchical_query/cte/columns'
require 'active_record/hierarchical_query/cte/join_builder'
require 'active_record/hierarchical_query/cte/orderings'
require 'active_record/hierarchical_query/cte/union_term'

module ActiveRecord
  module HierarchicalQuery
    module CTE
      class Query
        attr_reader :builder,
                    :columns,
                    :orderings

        delegate :klass, :table, :to => :builder

        # @param [ActiveRecord::HierarchicalQuery::Builder] builder
        def initialize(builder)
          @builder = builder
          @orderings = Orderings.new(builder)
          @columns = Columns.new(self)
        end

        def build_join(relation)
          JoinBuilder.new(self, relation).build
        end

        # @return [Arel::SelectManager]
        def arel
          apply_ordering { build_arel }
        end

        # @return [Arel::Table]
        def recursive_table
          @recursive_table ||= Arel::Table.new("#{table.name}__recursive")
        end

        def join_conditions
          builder.connect_by_value[recursive_table, table]
        end

        def order_clause
          recursive_table[orderings.column_name].asc
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

        def apply_ordering
          arel = yield

          if should_order?
            apply_ordering_to(arel)
          else
            arel
          end
        end

        def build_arel
          Arel::SelectManager.new(table.engine).
            with(:recursive, with_query).
            from(recursive_table).
            project(recursive_table[Arel.star]).
            take(builder.limit_value).
            skip(builder.offset_value)
        end

        def should_order?
          orderings.any? && builder.limit_value || builder.offset_value
        end

        def apply_ordering_to(select_manager)
          select_manager.order(order_clause)
        end
      end
    end
  end
end