# coding: utf-8

require 'active_record/hierarchical_query/visitors/visitor'

module ActiveRecord
  module HierarchicalQuery
    module Adapters
      # @api private
      class Abstract
        attr_reader :query,
                    :table

        delegate :klass, :to => :query

        class << self
          def visitors(*visitors_classes)
            define_method :visitors do
              @visitors ||= visitors_classes.map { |klass| klass.new(@query) }
            end
          end
        end

        # @param [ActiveRecord::HierarchicalQuery::CTE::Query] query
        def initialize(query)
          @query = query
          @table = klass.arel_table
        end

        # @example
        #   visit(:recursive_term, recursive_term.arel)
        def visit(kind, object)
          method_name = "visit_#{kind}"

          visitors.reduce(object) do |*, visitor|
            visitor.send(method_name, object) if visitor.respond_to?(method_name)
          end
        end
      end
    end
  end
end