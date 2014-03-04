# coding: utf-8

require 'active_support/core_ext/module/delegation'
require 'arel/visitors/depth_first'
require 'active_record/hierarchical_query/adapters/orderings_extractor'

module ActiveRecord
  module HierarchicalQuery
    module Adapters
      class PostgreSQL
        attr_reader :builder,
                    :table

        delegate :klass, :to => :builder

        # @param [ActiveRecord::HierachicalQuery::Builder] builder
        def initialize(builder)
          @builder = builder
          @table = klass.arel_table
          @orderings_extractor = OrderingsExtractor.new(builder)
        end

        def build_relation
          build_arel.order(@orderings_extractor.order_clause_values(recursive_table))
        end

        def build_join(joined_to)
          as_stmt = Arel::Nodes::As.new(build_arel, recursive_table)

          constraint = joined_to.table[joined_to.klass.primary_key].eq(recursive_table[klass.primary_key])
          join = Arel::Nodes::InnerJoin.new(as_stmt, Arel::Nodes::On.new(constraint))

          joined_to.joins(join.to_sql).order(@orderings_extractor.order_clause_values(recursive_table))
        end

        def build_arel
          union = original_term.union(:all, recursive_term)
          as_stmt = Arel::Nodes::As.new(recursive_table, union)

          Arel::SelectManager.new(table.engine).
              with(:recursive, as_stmt).
              from(recursive_table).
              project(recursive_table[Arel.star]).
              take(builder.limit_value).
              skip(builder.offset_value)
        end

        private
        # returns original (non-recursive) term of CTE
        def original_term
          (builder.start_with_value || klass).
            select(common_columns + @orderings_extractor.original_term_columns).
            except(:order, :limit, :offset).
            arel
        end

        def recursive_term
          arel = builder.child_scope_value.
            select(common_columns + @orderings_extractor.recursive_term_columns(recursive_table)).
            arel

          arel.join(recursive_table).on(join_conditions)
        end

        def recursive_table
          @recursive_table ||= Arel::Table.new("#{table.name}__recursive")
        end

        # returns columns to be selected from both terms
        def common_columns
          [klass.primary_key] | extract_columns_from_connect_by
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
      end # class PostgreSQL
    end # module Adapters
  end # module HierarchicalQuery
end # module ActiveRecord