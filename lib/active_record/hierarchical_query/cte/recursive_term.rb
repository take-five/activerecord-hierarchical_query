module ActiveRecord
  module HierarchicalQuery
    module CTE
      class RecursiveTerm
        # @return [ActiveRecord::HierarchicalQuery::CTE::Query]
        attr_reader :query

        delegate :recursive_table,
                 :join_conditions,
                 :to => :query

        # @param [ActiveRecord::HierarchicalQuery::CTE::Query] query
        def initialize(query)
          @query = query
        end

        def arel
          arel = scope.select(query.columns)
                      .arel
                      .join(recursive_table).on(join_conditions)

          arel.project(*query.orderings.recursive_projections)

          query.cycle_detector.apply_to_recursive(arel)
        end

        private
        def scope
          query.builder.child_scope_value
        end
      end
    end
  end
end