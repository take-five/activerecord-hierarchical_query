module ActiveRecord
  module HierarchicalQuery
    class JoinBuilder
      # @param [ActiveRecord::HierarchicalQuery::CTE::Query] query
      # @param [ActiveRecord::Relation] join_to
      # @param [#to_s] subquery_alias
      def initialize(query, join_to, subquery_alias)
        @query = query
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

      def primary_key
        @relation.table[@relation.klass.primary_key]
      end

      def foreign_key
        @alias[@query.klass.primary_key]
      end

      def constraint
        Arel::Nodes::On.new(primary_key.eq(foreign_key))
      end

      def subquery
        Arel::Nodes::Grouping.new(@query.arel.ast)
      end

      def aliased_subquery
        Arel::Nodes::As.new(subquery, @alias)
      end

      def apply_orderings(relation)
        if (orderings = @query.orderings.joined_relation_orderings).any?
          relation.order(*orderings)
        else
          relation
        end
      end
    end
  end
end