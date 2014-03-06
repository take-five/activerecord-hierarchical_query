# coding: utf-8

require 'arel/nodes/postgresql'

module ActiveRecord
  module HierarchicalQuery
    module Adapters
      # For PostgreSQL adapter
      #
      # @api private
      class OrderingsExtractor
        ORDERING_COLUMN_ALIAS = '__order_column'

        attr_reader :builder, :table

        def initialize(builder)
          @builder = builder
          @table = builder.klass.arel_table
        end

        def original_term_ordering
          return [] if orderings.empty?

          [Arel::Nodes::PostgresArray.new([row_number]).as(ORDERING_COLUMN_ALIAS)]
        end

        def recursive_term_ordering(recursive_table)
          return [] if orderings.empty?

          [Arel::Nodes::ArrayConcat.new(recursive_table[ORDERING_COLUMN_ALIAS], row_number)]
        end

        def order_clause(recursive_table)
          return [] if orderings.empty?

          recursive_table[ORDERING_COLUMN_ALIAS].asc
        end

        private
        def row_number
          Arel.sql("ROW_NUMBER() OVER (ORDER BY #{orderings.map(&:to_sql).join(', ')})")
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
                expr.strip!
                if expr.gsub!(/\s+desc\z/i, '')
                  Arel.sql(expr).desc
                else
                  expr.gsub!(/\s+asc\z/i, '')
                  Arel.sql(expr).asc
                end
              end

            else
              raise 'Unknown expression in ORDER BY SIBLINGS clause'
          end
        end
      end # class OrderingsExtractor
    end # module Adapters
  end # module HierarchicalQuery
end # module ActiveRecord