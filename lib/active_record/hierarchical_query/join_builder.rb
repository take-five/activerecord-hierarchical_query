require 'active_record/hierarchical_query/cte/query_builder'

module ActiveRecord
  module HierarchicalQuery
    class JoinBuilder
      # @param [ActiveRecord::HierarchicalQuery::Query] query
      # @param [ActiveRecord::Relation] join_to
      # @param [#to_s] subquery_alias
      def initialize(query, join_to, subquery_alias)
        @query = query
        @builder = CTE::QueryBuilder.new(query)
        @relation = join_to
        @alias = Arel::Table.new(subquery_alias, ActiveRecord::Base)
      end

      def build
        relation = @relation.joins(inner_join.to_sql)

        apply_orderings(relation)
      end

      private
      def inner_join
        Arel::Nodes::InnerJoin.new(aliased_subquery, constraint)
      end

      def aliased_subquery
        Arel::Nodes::As.new(subquery, @alias)
      end

      def subquery
        Arel::Nodes::Grouping.new(cte_arel.ast)
      end

      def cte_arel
        @cte_arel ||= @builder.build_arel
      end

      def constraint
        Arel::Nodes::On.new(primary_key.eq(foreign_key))
      end

      def primary_key
        @relation.table[@relation.klass.primary_key]
      end

      def foreign_key
        @alias[@query.klass.primary_key]
      end

      def apply_orderings(relation)
        if @query.orderings.any?
          relation.order(@query.recursive_table[@query.ordering_column_name].asc)
        else
          relation
        end
      end
    end
  end
end