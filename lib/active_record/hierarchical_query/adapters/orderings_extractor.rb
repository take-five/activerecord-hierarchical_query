# coding: utf-8

require 'arel/nodes/postgresql'

module ActiveRecord
  module HierarchicalQuery
    module Adapters
      # For PostgreSQL adapter
      #
      # @api private
      class OrderingsExtractor
        ALIAS_PREFIX = '__order_column_'

        attr_reader :builder, :table

        def initialize(builder)
          @builder = builder
          @table = builder.klass.arel_table
        end

        def original_term_columns
          columns.each_with_index.map do |column, i|
            ary = Arel::Nodes::PostgresArray.new([column])
            Arel::Nodes::As.new(ary, build_alias(i))
          end
        end

        def recursive_term_columns(recursive_table)
          columns.each_with_index.map do |column, i|
            Arel::Nodes::ArrayConcat.new(build_alias(i, recursive_table), column)
          end
        end

        def order_clause_values(table)
          orderings.each_with_index.map do |ordering, i|
            if ordering.ascending?
              build_alias(i, table).asc
            else
              build_alias(i, table).desc
            end
          end
        end

        private
        def columns
          orderings.map(&:expr)
        end

        def orderings
          @orderings ||= builder.order_values.each_with_object([]) do |value, orderings|
            orderings.concat Array.wrap(as_orderings(value))
          end
        end

        def build_alias(index, table = nil)
          aliaz = Arel.sql("#{ALIAS_PREFIX}#{index}")
          aliaz = table[aliaz] if table
          aliaz
        end

        def as_orderings(value)
          case value
            when Arel::Nodes::Ordering
              value

            when Arel::Nodes::Node
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