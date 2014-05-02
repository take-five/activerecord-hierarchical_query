# coding: utf-8

require 'active_support/core_ext/hash/keys'
require 'active_support/core_ext/string/inflections'

module ActiveRecord
  module HierarchicalQuery
    module Adapters
      SUPPORTED_ADAPTERS = %w(PostgreSQL)

      ADAPTERS = Hash[
        :PostgreSQL => :PostgreSQL,
        :PostGIS => :PostgreSQL,
        :OracleEnhanced => :Oracle
      ].stringify_keys

      def self.autoload(name, path = name.to_s.underscore)
        super name, "active_record/hierarchical_query/adapters/#{path}"
      end

      autoload :PostgreSQL, 'postgresql'
      autoload :Oracle

      def self.lookup(klass)
        name = klass.connection.adapter_name

        raise 'Your database %s does not support recursive queries' % name unless
            ADAPTERS.key?(name)

        const_get(ADAPTERS[name])
      end
    end # module Adapters
  end # module HierarchicalQuery
end # module ActiveRecord
