require 'arel/visitors/depth_first'

module ActiveRecord
  module HierarchicalQuery
    module CTE
      class Columns
        # @param [ActiveRecord::HierarchicalQuery::Query] query
        def initialize(query)
          @query = query
        end

        # returns columns to be selected from both recursive and non-recursive terms
        def to_a
          column_names = [@query.klass.primary_key] | connect_by_columns
          column_names.map { |name| @query.table[name] }
        end
        alias_method :to_ary, :to_a

        private
        def connect_by_columns
          @query.join_conditions.grep(Arel::Attributes::Attribute) { |column| column.name.to_s }
        end
      end
    end
  end
end