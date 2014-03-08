# coding: utf-8

require 'active_record/hierarchical_query/adapters'
require 'active_record/hierarchical_query/cte/columns'
require 'active_record/hierarchical_query/cte/union_term'

module ActiveRecord
  module HierarchicalQuery
    module CTE
      # CTE query builder
      class Query
        attr_reader :builder,
                    :adapter,
                    :columns

        delegate :klass, :table, :to => :builder

        # @param [ActiveRecord::HierarchicalQuery::Builder] builder
        def initialize(builder)
          @builder = builder
          @adapter = Adapters.lookup(klass).new(self)
          @columns = Columns.new(self)
        end

        # @return [Arel::SelectManager]
        def arel
          adapter.visit(:cte, build_arel)
        end

        # @return [Arel::Table]
        def recursive_table
          @recursive_table ||= Arel::Table.new("#{table.name}__recursive")
        end

        def join_conditions
          builder.connect_by_value[recursive_table, table]
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

        def build_arel
          Arel::SelectManager.new(table.engine).
            with(:recursive, with_query).
            from(recursive_table).
            project(recursive_table[Arel.star]).
            take(builder.limit_value).
            skip(builder.offset_value)
        end
      end
    end
  end
end