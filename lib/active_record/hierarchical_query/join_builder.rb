require 'active_record/hierarchical_query/cte/query_builder'

module ActiveRecord
  module HierarchicalQuery
    class JoinBuilder
      # @param [ActiveRecord::HierarchicalQuery::Query] query
      # @param [ActiveRecord::Relation] join_to
      # @param [#to_s] subquery_alias
      # @param [Hash] options (:outer_join_hierarchical, :union_type)
      def initialize(query, join_to, subquery_alias, options = {})
        @query = query
        @builder = CTE::QueryBuilder.new(query, options: options)
        @relation = join_to
        @alias = Arel::Table.new(subquery_alias)
        @options = options
      end

      def build
        relation = @relation.joins(joined_arel_node)
        # copy bound variables from inner subquery
        relation.bind_values += bind_values
        # add ordering by "__order_column"
        relation.order_values += order_columns if ordered?

        relation
      end

      private
      def joined_arel_node
        @options[:outer_join_hierarchical] == true ? outer_join : inner_join
      end

      def inner_join
        Arel::Nodes::InnerJoin.new(aliased_subquery, constraint)
      end

      def outer_join
        Arel::Nodes::OuterJoin.new(aliased_subquery, constraint)
      end

      def aliased_subquery
        SubqueryAlias.new(subquery, @alias)
      end

      def subquery
        Arel::Nodes::Grouping.new(cte_arel.ast)
      end

      def cte_arel
        @cte_arel ||= @builder.build_arel
      end

      def constraint
        Arel::Nodes::On.new(primary_key.eq(foreign_key))
      end

      def primary_key
        @relation.table[@relation.klass.primary_key]
      end

      def custom_foreign_key
        @options[:foreign_key]
      end

      def foreign_key
        custom_foreign_key ? @alias[custom_foreign_key] : @alias[@query.klass.primary_key]
      end

      def bind_values
        @builder.bind_values
      end

      def ordered?
        @query.orderings.any?
      end

      def order_columns
        [@query.recursive_table[@query.ordering_column_name].asc]
      end

      # This node is required to support joins to aliased Arel nodes
      class SubqueryAlias < Arel::Nodes::As
        attr_reader :table_name

        def initialize(subquery, alias_node)
          super
          @table_name = alias_node.name
        end
      end
    end
  end
end
