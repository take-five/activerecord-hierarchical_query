module ActiveRecord
  module HierarchicalQuery
    module CTE
      class JoinBuilder
        # @param [ActiveRecord::HierarchicalQuery::CTE::Query] query
        # @param [ActiveRecord::Relation] join_to
        def initialize(query, join_to)
          @query = query
          @relation = join_to
        end

        def build
          apply_ordering { @relation.joins(inner_join.to_sql) }
        end

        private
        def inner_join
          Arel::Nodes::InnerJoin.new(aliased_subquery, constraint)
        end

        def primary_key
          @relation.table[@relation.klass.primary_key]
        end

        def foreign_key
          @query.recursive_table[@query.klass.primary_key]
        end

        def constraint
          Arel::Nodes::On.new(primary_key.eq(foreign_key))
        end

        def subquery
          Arel::Nodes::Grouping.new(@query.arel.ast)
        end

        def aliased_subquery
          Arel::Nodes::As.new(subquery, @query.recursive_table)
        end

        def apply_ordering
          scope = yield

          if @query.orderings.any?
            scope.order(@query.order_clause)
          else
            scope
          end
        end
      end
    end
  end
end