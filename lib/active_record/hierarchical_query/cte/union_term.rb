require 'active_record/hierarchical_query/cte/non_recursive_term'
require 'active_record/hierarchical_query/cte/recursive_term'

module ActiveRecord
  module HierarchicalQuery
    module CTE
      class UnionTerm
        # @param [ActiveRecord::HierarchicalQuery::CTE::QueryBuilder] builder
        def initialize(builder)
          @builder = builder
        end

        def arel
          non_recursive_term.union(:all, recursive_term)
        end

        private
        def recursive_term
          RecursiveTerm.new(@builder).arel
        end

        def non_recursive_term
          NonRecursiveTerm.new(@builder).arel
        end
      end
    end
  end
end