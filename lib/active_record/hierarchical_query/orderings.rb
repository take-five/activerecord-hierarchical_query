module ActiveRecord
  module HierarchicalQuery
    class Orderings
      NATURAL_SORT_TYPES = Set[
          :integer, :float, :decimal,
          :datetime, :timestamp, :time, :date,
          :boolean, :itet, :cidr, :ltree
      ]

      include Enumerable

      attr_reader :order_values, :table

      # @param [Array] order_values
      # @param [Arel::Table] table
      def initialize(order_values, table)
        @order_values, @table = order_values, table
        @values = nil # cached orderings
      end

      def each(&block)
        return @values.each(&block) if @values
        return enum_for(__method__) unless block_given?

        @values = []

        order_values.each do |value|
          Array.wrap(as_orderings(value)).each do |ordering|
            @values << ordering
          end
        end

        @values.each(&block)
      end

      # Returns order expression to be inserted into SELECT clauses of both
      # non-recursive and recursive terms.
      #
      # @return [Arel::Nodes::Node] order expression
      def row_number_expression
        if raw_ordering?
          order_attribute
        else
          Arel.sql("ROW_NUMBER() OVER (ORDER BY #{map(&:to_sql).join(', ')})")
        end
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

        if expr.gsub!(/\bdesc\z/i, '')
          Arel.sql(expr).desc
        else
          expr.gsub!(/\basc\z/i, '')
          Arel.sql(expr).asc
        end
      end

      def raw_ordering?
        ordered_by_attribute? &&
            (column = order_column) &&
            NATURAL_SORT_TYPES.include?(column.type)
      end

      def ordered_by_attribute?
        one? && first.ascending? && order_attribute.is_a?(Arel::Attributes::Attribute)
      end

      def order_attribute
        first.expr
      end

      def order_column
        table = order_attribute.relation

        engine = table.class.engine
        if engine == ActiveRecord::Base
          columns =
            if engine.connection.respond_to?(:schema_cache)
              engine.connection.schema_cache.columns_hash(table.name)
            else
              engine.connection_pool.columns_hash[table.name]
            end
        else
          columns = engine.columns_hash
        end

        columns[order_attribute.name.to_s]
      end
    end
  end
end
