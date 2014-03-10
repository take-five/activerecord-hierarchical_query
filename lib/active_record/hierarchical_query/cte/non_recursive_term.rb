# coding: utf-8

require 'arel/nodes/postgresql'

module ActiveRecord
  module HierarchicalQuery
    module CTE
      class NonRecursiveTerm
        DISALLOWED_CLAUSES = :order, :limit, :offset

        attr_reader :query
        delegate :builder, :orderings, :cycle_detector, :to => :query
        delegate :start_with_value, :klass, :to => :builder

        # @param [ActiveRecord::HierarchicalQuery::CTE::Query] query
        def initialize(query)
          @query = query
        end

        def arel
          arel = scope.select(query.columns)
                      .select(ordering_column)
                      .except(*DISALLOWED_CLAUSES)
                      .arel

          cycle_detector.visit_non_recursive(arel)
        end

        private
        def scope
          start_with_value || klass.__send__(HierarchicalQuery::DELEGATOR_SCOPE)
        end

        def ordering_column
          if orderings.any?
            Arel::Nodes::PostgresArray.new([orderings.row_number_expression]).as(orderings.column_name)
          else
            []
          end
        end
      end # class NonRecursiveTerm
    end
  end
end