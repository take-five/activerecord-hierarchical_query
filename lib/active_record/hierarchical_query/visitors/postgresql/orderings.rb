require 'active_record/hierarchical_query/visitors/orderings'

module ActiveRecord
  module HierarchicalQuery
    module Visitors
      module PostgreSQL
        class Orderings < Visitors::Orderings
          NATURAL_SORT_TYPES = Set[
              :integer, :float, :decimal,
              :datetime, :timestamp, :time, :date,
              :boolean, :itet, :cidr, :ltree
          ]

          delegate :first, :to => :orderings

          def visit_non_recursive(arel)
            project(arel) do
              Arel::Nodes::PostgresArray.new([row_number_expression]).as(column_name)
            end
          end

          def visit_recursive(arel)
            project(arel) do
              Arel::Nodes::ArrayConcat.new(recursive_table[column_name], row_number_expression)
            end
          end

          private
          def project(arel)
            visit(arel) { arel.project(yield) }
          end

          def row_number_expression
            if raw_ordering?
              order_attribute
            else
              Arel.sql("ROW_NUMBER() OVER (ORDER BY #{orderings.map(&:to_sql).join(', ')})")
            end
          end

          def raw_ordering?
            ordered_by_attribute? &&
                (column = order_column) &&
                NATURAL_SORT_TYPES.include?(column.type)
          end

          def ordered_by_attribute?
            orderings.one? && first.ascending? && order_attribute.is_a?(Arel::Attributes::Attribute)
          end

          def order_attribute
            first.expr
          end

          def order_column
            table = order_attribute.relation

            if table.engine == ActiveRecord::Base
              columns = table.engine.connection_pool.columns_hash[table.name]
            else
              columns = table.engine.columns_hash
            end

            columns[order_attribute.name.to_s]
          end
        end
      end
    end
  end
end