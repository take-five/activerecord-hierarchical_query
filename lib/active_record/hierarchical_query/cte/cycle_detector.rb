# coding: utf-8

module ActiveRecord
  module HierarchicalQuery
    module CTE
      class CycleDetector
        COLUMN_NAME = '__path'.freeze

        attr_reader :query

        delegate :builder, :to => :query
        delegate :klass, :table, :to => :builder

        # @param [ActiveRecord::HierarchicalQuery::CTE::Query] query
        def initialize(query)
          @query = query
        end

        def column_name
          COLUMN_NAME
        end

        def visit_non_recursive(arel)
          visit arel do
            arel.project Arel::Nodes::PostgresArray.new([primary_key]).as(column_name)
          end
        end

        def visit_recursive(arel)
          visit arel do
            arel.project Arel::Nodes::ArrayConcat.new(parent_column, primary_key)
            arel.constraints << Arel::Nodes::Not.new(primary_key.eq(any(parent_column)))
          end
        end

        private
        def enabled?
          builder.nocycle_value
        end

        def parent_column
          query.recursive_table[column_name]
        end

        def primary_key
          table[klass.primary_key]
        end

        def visit(object)
          if enabled?
            yield
          end

          object
        end

        def any(argument)
          Arel::Nodes::NamedFunction.new('ANY', [argument])
        end
      end
    end
  end
end