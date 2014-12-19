module ActiveRecord
  module HierarchicalQuery
    module Visitors
      class Orderings < Visitor
        ORDERING_COLUMN_ALIAS = '__order_column'

        delegate :recursive_table, :to => :query

        def visit_joined_relation(relation)
          visit(relation) do
            relation.order(order_clause)
          end
        end

        def visit_cte(select_manager)
          if should_order_cte?
            select_manager.order(order_clause)
          else
            select_manager
          end
        end

        protected
        def visit(object)
          if orderings.any?
            yield
          else
            object
          end
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

        def column_name
          ORDERING_COLUMN_ALIAS
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
      end
    end
  end
end