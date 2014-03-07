require 'active_record/hierarchical_query/cte/non_recursive_term'
require 'active_record/hierarchical_query/cte/recursive_term'

module ActiveRecord
  module HierarchicalQuery
    module CTE
      class UnionTerm
        # @param [ActiveRecord::HierarchicalQuery::CTE::Query] query
        def initialize(query)
          @query = query
        end

        def arel
          non_recursive_term.union(:all, recursive_term)
        end

        private
        def recursive_term
          RecursiveTerm.new(@query).arel
        end

        def non_recursive_term
          NonRecursiveTerm.new(@query).arel
        end
      end
    end
  end
end