module ActiveRecord
  module HierarchicalQuery
    module CTE
      class RecursiveTerm
        # @return [ActiveRecord::HierarchicalQuery::CTE::Query]
        attr_reader :builder

        delegate :recursive_table,
                 :join_conditions,
                 :to => :builder

        # @param [ActiveRecord::HierarchicalQuery::CTE::QueryBuilder] builder
        def initialize(builder)
          @builder = builder
        end

        def arel
          arel = scope.select(builder.columns)
                      .arel
                      .join(recursive_table).on(join_conditions)

          arel.project(*builder.orderings.recursive_projections)

          builder.cycle_detector.apply_to_recursive(arel)
        end

        private
        def scope
          builder.query.child_scope_value
        end
      end
    end
  end
end