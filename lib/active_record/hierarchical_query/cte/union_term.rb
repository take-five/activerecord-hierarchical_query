require 'active_record/hierarchical_query/cte/non_recursive_term'
require 'active_record/hierarchical_query/cte/recursive_term'

module ActiveRecord
  module HierarchicalQuery
    module CTE
      class UnionTerm
        # @param [ActiveRecord::HierarchicalQuery::CTE::QueryBuilder] builder
        def initialize(builder, options = {})
          @builder = builder
          @union_type = options.fetch(:union_type, :all)
        end

        def bind_values
          non_recursive_term
            .bind_values
            .merge recursive_term.bind_values
        end

        def arel
          non_recursive_term.arel.union(union_type, recursive_term.arel)
        end

        private
        attr_reader :union_type

        def recursive_term
          @rt ||= RecursiveTerm.new(@builder)
        end

        def non_recursive_term
          @nrt ||= NonRecursiveTerm.new(@builder)
        end
      end
    end
  end
end
