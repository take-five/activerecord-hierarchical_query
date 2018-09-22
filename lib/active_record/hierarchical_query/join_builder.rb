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
        relation = @relation

        # add ordering by "__order_column"
        relation.order_values += order_columns if ordered?

        relation = relation.joins(joined_arel_node)

        return relation unless ActiveRecord.version < Gem::Version.new("5.2")

        relation.bind_values += bind_values

        relation
      end

      private

      if ActiveRecord.version < Gem::Version.new("5.2")
        def bind_values
          @builder.bind_values
        end
      end

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

      def ordered?
        @query.orderings.any?
      end

      def order_columns
        [@query.recursive_table[@query.ordering_column_name].asc]
      end

      # This node is required to support joins to aliased Arel nodes
      class SubqueryAlias < Arel::Nodes::As

        attr_reader :table_name

        unless method_defined? :name
          alias_method :name, :table_name
        end

        def initialize(subquery, alias_node)
          super

          @table_name = alias_node.try :name

          return unless alias_node.respond_to? :left

          aliased_name = alias_node.left.relation.name
          return if @table_name == aliased_name

          # Defensive coding; this shouldn't happen unless the
          # Rails team does a change to how Arel works.
          message = "Unexpected alias name mismatch"
          raise RuntimeError, message
        end

      end
    end
  end
end
