module ActiveRecord
  module HierarchicalQuery
    module Visitors
      # @api private
      class Visitor
        attr_reader :query

        delegate :builder, :to => :query
        delegate :klass, :table, :to => :builder

        def initialize(query)
          @query = query
        end
      end
    end
  end
end