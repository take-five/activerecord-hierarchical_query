require 'arel/visitors/depth_first'

module ActiveRecord
  module HierarchicalQuery
    module CTE
      class Columns
        # @param [ActiveRecord::HierarchicalQuery::CTE::QueryBuilder] builder
        def initialize(builder)
          @builder = builder
        end

        # returns columns to be selected from both recursive and non-recursive terms
        def to_a
          column_names = [@builder.klass.primary_key] | connect_by_columns
          column_names.map { |name| @builder.table[name] }
        end
        alias_method :to_ary, :to_a

        private
        def connect_by_columns
          extract_from(@builder.join_conditions).map { |column| column.name.to_s }
        end

        def extract_from(arel)
          target = []

          visitor = Arel::Visitors::DepthFirst.new do |node|
            target << node if node.is_a?(Arel::Attributes::Attribute)
          end
          visitor.accept(arel)

          target
        end
      end
    end
  end
end