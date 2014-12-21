# coding: utf-8

require 'active_support/lazy_load_hooks'

require 'active_record/hierarchical_query/version'
require 'active_record/hierarchical_query/query'
require 'active_record/version'

module ActiveRecord
  module HierarchicalQuery
    # @api private
    DELEGATOR_SCOPE = ActiveRecord::VERSION::STRING < '4.0.0' ? :scoped : :all

    # Performs a join to recursive subquery
    # which should be built within a block.
    #
    # @example
    #   MyModel.join_recursive do |query|
    #     query.start_with(parent_id: nil)
    #          .connect_by(id: :parent_id)
    #          .where('depth < ?', 5)
    #          .order_siblings(name: :desc)
    #   end
    #
    # @param [Hash] join_options
    # @option join_options [String, Symbol] :as aliased name of joined
    #   table (`%table_name%__recursive` by default)
    # @yield [query]
    # @yieldparam [ActiveRecord::HierarchicalQuery::Query] query Hierarchical query
    # @raise [ArgumentError] if block is omitted
    def join_recursive(join_options = {}, &block)
      raise ArgumentError, 'block expected' unless block_given?

      query = Query.new(klass)

      if block.arity == 0
        query.instance_eval(&block)
      else
        block.call(query)
      end

      query.join_to(self, join_options)
    end
  end
end

ActiveSupport.on_load(:active_record, yield: true) do |base|
  class << base
    delegate :join_recursive, to: ActiveRecord::HierarchicalQuery::DELEGATOR_SCOPE
  end

  ActiveRecord::Relation.send :include, ActiveRecord::HierarchicalQuery
end