# coding: utf-8

require 'active_support/lazy_load_hooks'

require 'active_record/hierarchical_query/version'
require 'active_record/hierarchical_query/builder'
require 'active_record/version'

module ActiveRecord
  # If a table contains hierarchical data, then you can select rows
  # in hierarchical order using hierarchical query builder.
  #
  # Hierarchical queries consist of these important clauses:
  #
  # ### START WITH clause
  # This clause specifies the root row(s) of the hierarchy.
  #
  # ### CONNECT BY clause
  # This clause specifies relationship between parent rows
  # and child rows of the hierarchy.
  #
  # ### ORDER SIBLINGS clause
  # This clause specifies an order of rows in which they
  # appear on each hierarchy level.
  #
  # These terms are borrowed from {http://docs.oracle.com/cd/B19306_01/server.102/b14200/queries003.htm Oracle hierarchical queries syntax}.
  #
  # Method {#join_recursive} should be used to build hierarchical query.
  # This method accepts block to which {ActiveRecord::HierarchicalQuery::Builder}
  # instance is passed.
  #
  # @example Traverse nodes recursively starting from root rows connected by `parent_id` column ordered by `name`.
  #   MyModel.join_recursive do |query|
  #     query.connect_by(:id => :parent_id)
  #          .start_with(:parent_id => nil)
  #          .order_siblings(:name)
  #   end
  #
  # Hierarchical queries are processed as follows:
  #
  # * First, root rows are selected -- those rows that satisfy `START WITH` condition in
  #   order specified by `ORDER SIBLINGS` clause. In example above it's specified by
  #   statements `query.start_with(:parent_id => nil)` and `query.order_siblings(:name)`.
  # * Second, child rows for each root rows are selected. Each child row must satisfy
  #   condition specified by `CONNECT BY` clause with respect to one of the root rows
  #   (`query.connect_by(:id => :parent_id)` in example above). Order of child rows is
  #   also specified by `ORDER SIBLINGS` clause.
  # * Successive generations of child rows are selected with respect to `CONNECT BY` clause.
  #   First the children of each row selected in step 2 selected, then the children of those
  #   children and so on.
  module HierarchicalQuery
    # @api private
    DELEGATOR_SCOPE = ActiveRecord::VERSION::STRING < '4.0.0' ? :scoped : :all

    # Performs a join to recursive subquery
    # which should be built within a block.
    #
    # @example
    #   MyModel.join_recursive do |query|
    #     query.start_with(:parent_id => nil)
    #          .connect_by(:id => :parent_id)
    #          .where('depth < ?', 5)
    #          .order_siblings(:name => :desc)
    #   end
    #
    # @yield [query]
    # @yieldparam [ActiveRecord::HierarchicalQuery::Builder] query Hierarchical query builder
    # @raise [ArgumentError] if block is omitted
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