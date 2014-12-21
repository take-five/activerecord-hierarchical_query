module ActiveRecord
  module HierarchicalQuery
    module CTE
      class CycleDetector
        COLUMN_NAME = '__path'.freeze

        delegate :klass, :table, to: :@query

        # @param [ActiveRecord::HierarchicalQuery::Query] query
        def initialize(query)
          @query = query
        end

        def apply_to_non_recursive(arel)
          if enabled?
            arel.project Arel::Nodes::PostgresArray.new([primary_key]).as(column_name)
          end

          arel
        end

        def apply_to_recursive(arel)
          if enabled?
            arel.project Arel::Nodes::ArrayConcat.new(parent_column, primary_key)
            arel.constraints << Arel::Nodes::Not.new(primary_key.eq(any(parent_column)))
          end

          arel
        end

        private
        def enabled?
          @query.nocycle_value
        end

        def column_name
          COLUMN_NAME
        end

        def parent_column
          @query.recursive_table[column_name]
        end

        def primary_key
          table[klass.primary_key]
        end

        def any(argument)
          Arel::Nodes::NamedFunction.new('ANY', [argument])
        end
      end
    end
  end
end