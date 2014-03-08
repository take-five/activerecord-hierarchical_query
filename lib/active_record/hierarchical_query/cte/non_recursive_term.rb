# coding: utf-8

module ActiveRecord
  module HierarchicalQuery
    module CTE
      class NonRecursiveTerm
        DISALLOWED_CLAUSES = :order, :limit, :offset, :group, :having

        attr_reader :query
        delegate :builder, :adapter, :to => :query
        delegate :start_with_value, :klass, :to => :builder

        # @param [ActiveRecord::HierarchicalQuery::CTE::Query] query
        def initialize(query)
          @query = query
        end

        def arel
          arel = scope.select(query.columns)
                      .except(*DISALLOWED_CLAUSES)
                      .arel

          adapter.visit(:non_recursive, arel)
        end

        private
        def scope
          start_with_value || klass.__send__(HierarchicalQuery::DELEGATOR_SCOPE)
        end
      end # class NonRecursiveTerm
    end
  end
end