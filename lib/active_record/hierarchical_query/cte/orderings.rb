require 'set'
require 'active_support/core_ext/array/wrap'

module ActiveRecord
  module HierarchicalQuery
    module CTE
      class Orderings
        include Enumerable

        ORDERING_COLUMN_ALIAS = '__order_column'

        NATURAL_SORT_TYPES = Set[
            :integer, :float, :decimal,
            :datetime, :timestamp, :time, :date,
            :boolean, :itet, :cidr, :ltree
        ]

        delegate :table, :to => :@builder
        delegate :each, :to => :arel_nodes

        # @param [ActiveRecord::HierarchicalQuery::Builder] builder
        def initialize(builder)
          @builder = builder
        end

        def arel_nodes
          @arel_nodes ||= @builder.order_values.each_with_object([]) do |value, orderings|
            orderings.concat Array.wrap(as_orderings(value))
          end
        end

        def row_number_expression
          if raw_ordering?
            order_attribute
          else
            Arel.sql("ROW_NUMBER() OVER (ORDER BY #{arel_nodes.map(&:to_sql).join(', ')})")
          end
        end

        def column_name
          ORDERING_COLUMN_ALIAS
        end

        private
        def as_orderings(value)
          case value
            when Arel::Nodes::Ordering
              value

            when Arel::Nodes::Node, Arel::Attributes::Attribute
              value.asc

            when Symbol
              table[value].asc

            when Hash
              value.map { |field, dir| table[field].send(dir) }

            when String
              value.split(',').map do |expr|
                string_as_ordering(expr)
              end

            else
              raise 'Unknown expression in ORDER BY SIBLINGS clause'
          end
        end

        def string_as_ordering(expr)
          expr.strip!

          if expr.gsub!(/\s+desc\z/i, '')
            Arel.sql(expr).desc
          else
            expr.gsub!(/\s+asc\z/i, '')
            Arel.sql(expr).asc
          end
        end

        def raw_ordering?
          ordered_by_attribute? &&
              (column = order_column) &&
              NATURAL_SORT_TYPES.include?(column.type)
        end

        def ordered_by_attribute?
          arel_nodes.one? && first.ascending? && order_attribute.is_a?(Arel::Attributes::Attribute)
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
      end # class Orderings
    end
  end
end