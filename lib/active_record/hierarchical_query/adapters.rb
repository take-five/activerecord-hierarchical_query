# coding: utf-8

module ActiveRecord
  module HierarchicalQuery
    module Adapters
      SUPPORTED_ADAPTERS = %w(PostgreSQL)

      autoload :PostgreSQL, 'active_record/hierarchical_query/adapters/postgresql'

      def self.lookup(klass)
        name = klass.connection.adapter_name

        raise 'Your database does not support recursive queries' unless
            SUPPORTED_ADAPTERS.include?(name)

        const_get(name)
      end
    end # module Adapters
  end # module HierarchicalQuery
end # module ActiveRecord