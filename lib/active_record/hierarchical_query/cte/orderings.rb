module ActiveRecord
  module HierarchicalQuery
    module CTE
      class Orderings
        ORDERING_COLUMN_ALIAS = '__order_column'.freeze
        NATURAL_SORT_TYPES = Set[
            :integer, :float, :decimal,
            :datetime, :timestamp, :time, :date,
            :boolean, :itet, :cidr, :ltree
        ]

        attr_reader :query

        delegate :builder, :recursive_table, :to => :query
        delegate :klass, :table, :to => :builder
        delegate :first, :to => :orderings

        # @param [ActiveRecord::HierarchicalQuery::CTE::Query] query
        def initialize(query)
          @query = query
        end

        def non_recursive_projections
          if orderings.any?
            [Arel::Nodes::PostgresArray.new([row_number_expression]).as(column_name)]
          else
            []
          end
        end

        def recursive_projections
          if orderings.any?
            [Arel::Nodes::ArrayConcat.new(recursive_table[column_name], row_number_expression)]
          else
            []
          end
        end

        def cte_orderings
          if should_order_cte?
            [order_clause]
          else
            []
          end
        end

        def joined_relation_orderings
          if orderings.any?
            [order_clause]
          else
            []
          end
        end

        private
        def column_name
          ORDERING_COLUMN_ALIAS
        end

        def order_clause
          recursive_table[column_name].asc
        end

        def should_order_cte?
          orderings.any? && (builder.limit_value || builder.offset_value)
        end

        def orderings
          @orderings ||= builder.order_values.each_with_object([]) do |value, orderings|
            orderings.concat Array.wrap(as_orderings(value))
          end
        end

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

          if expr.gsub!(/\bdesc\z/i, '')
            Arel.sql(expr).desc
          else
            expr.gsub!(/\basc\z/i, '')
            Arel.sql(expr).asc
          end
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