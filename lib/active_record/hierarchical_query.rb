# coding: utf-8

require 'active_support/lazy_load_hooks'

require 'active_record/hierarchical_query/version'
require 'active_record/hierarchical_query/builder'
require 'active_record/version'

module ActiveRecord
  module HierarchicalQuery
    # @api private
    DELEGATOR_SCOPE = ActiveRecord::VERSION::STRING < '4.0.0' ? :scoped : :all

    # Performs a join to recursive subquery
    # which should be built within a block.
    #
    # @example
    #   MyModel.join_recursive do |hierarchy|
    #     hierarchy.start_with(:parent_id => nil)
    #              .connect_by(:id => :parent_id)
    #              .where('depth < ?', 5)
    #              .order_siblings(:name => :desc)
    #   end
    def join_recursive(&block)
      raise ArgumentError, 'block expected' unless block_given?

      builder = Builder.new(klass).tap(&block)

      builder.join_to(self)
    end
  end
end

ActiveSupport.on_load(:active_record, :yield => true) do |base|
  class << base
    delegate :join_recursive, :to => ActiveRecord::HierarchicalQuery::DELEGATOR_SCOPE
  end

  ActiveRecord::Relation.send :include, ActiveRecord::HierarchicalQuery
end