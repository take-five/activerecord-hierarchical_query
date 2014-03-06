# coding: utf-8

require 'active_support/core_ext/module/delegation'
require 'arel/visitors/depth_first'
require 'active_record/hierarchical_query/adapters/orderings_extractor'

module ActiveRecord
  module HierarchicalQuery
    module Adapters
      # @api private
      class PostgreSQL
        attr_reader :builder,
                    :table

        delegate :klass, :to => :builder

        # @param [ActiveRecord::HierarchicalQuery::Builder] builder
        def initialize(builder)
          @builder = builder
          @table = klass.arel_table
          @orderings_extractor = OrderingsExtractor.new(self)
        end

        def build_join(joined_to)
          join = build_inner_join(joined_to)

          joined_to.
              joins(join.to_sql).
              order(@orderings_extractor.order_clause)
        end

        def recursive_table
          @recursive_table ||= Arel::Table.new("#{table.name}__recursive")
        end
        alias_method :prior, :recursive_table

        private
        def build_arel
          as_stmt = Arel::Nodes::As.new(recursive_table, union_term)

          manager = Arel::SelectManager.new(table.engine).
              with(:recursive, as_stmt).
              from(recursive_table).
              project(recursive_table[Arel.star]).
              take(builder.limit_value).
              skip(builder.offset_value)

          if builder.limit_value || builder.offset_value
            manager.order(*@orderings_extractor.order_clause)
          end

          manager
        end

        def union_term
          original_term.union(:all, recursive_term)
        end

        # returns original (non-recursive) term of CTE
        def original_term
          (builder.start_with_value || klass).
            select(common_columns).
            select(@orderings_extractor.original_term_ordering).
            except(:order, :limit, :offset).
            arel
        end

        def recursive_term
          table = builder.child_scope_value.arel_table

          arel = builder.child_scope_value.
            select(common_columns_for(table)).
            select(@orderings_extractor.recursive_term_ordering).
            arel

          arel.join(recursive_table).on(join_conditions)
        end

        # returns columns to be selected from both terms
        def common_columns
          [klass.primary_key] | extract_columns_from_connect_by
        end

        def common_columns_for(table)
          common_columns.map { |x| table[x] }
        end

        # extracts column names from connect by condition
        def extract_columns_from_connect_by
          columns = extract_columns_from_arel(join_conditions)
          columns.map { |column| column.name.to_s }
        end

        # extracts columns objects from arbitrary arel node
        def extract_columns_from_arel(arel)
          columns = []

          visitor = Arel::Visitors::DepthFirst.new do |node|
            columns << node if node.is_a?(Arel::Attributes::Attribute)
          end
          visitor.accept(arel)

          columns
        end

        def join_conditions
          builder.connect_by_value[recursive_table, table]
        end

        def build_inner_join(relation)
          as_stmt = Arel::Nodes::As.new(build_arel, recursive_table)

          constraint = relation.table[relation.klass.primary_key].eq(recursive_table[klass.primary_key])
          Arel::Nodes::InnerJoin.new(as_stmt, Arel::Nodes::On.new(constraint))
        end
      end # class PostgreSQL
    end # module Adapters
  end # module HierarchicalQuery
end # module ActiveRecord