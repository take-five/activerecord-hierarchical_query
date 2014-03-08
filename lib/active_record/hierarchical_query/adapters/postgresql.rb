# coding: utf-8

require 'arel/nodes/postgresql'

require 'active_record/hierarchical_query/adapters/abstract'
require 'active_record/hierarchical_query/visitors/postgresql/cycle_detector'
require 'active_record/hierarchical_query/visitors/postgresql/orderings'

module ActiveRecord
  module HierarchicalQuery
    module Adapters
      # @api private
      class PostgreSQL < Abstract
        visitors Visitors::PostgreSQL::CycleDetector,
                 Visitors::PostgreSQL::Orderings
      end # class PostgreSQL
    end # module Adapters
  end # module HierarchicalQuery
end # module ActiveRecord