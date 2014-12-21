# coding: utf-8

module ActiveRecord
  module HierarchicalQuery
    module CTE
      class NonRecursiveTerm
        DISALLOWED_CLAUSES = :order, :limit, :offset, :group, :having

        attr_reader :builder
        delegate :query, :to => :builder
        delegate :start_with_value, :klass, :to => :query

        # @param [ActiveRecord::HierarchicalQuery::CTE::QueryBuilder] builder
        def initialize(builder)
          @builder = builder
        end

        def arel
          arel = scope.select(builder.columns)
                      .except(*DISALLOWED_CLAUSES)
                      .arel

          arel.project(*builder.orderings.non_recursive_projections)

          builder.cycle_detector.apply_to_non_recursive(arel)
        end

        private
        def scope
          start_with_value || klass.__send__(HierarchicalQuery::DELEGATOR_SCOPE)
        end
      end # class NonRecursiveTerm
    end
  end
end