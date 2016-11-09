# coding: utf-8

require 'active_support/core_ext/array/extract_options'

require 'active_record/hierarchical_query/orderings'
require 'active_record/hierarchical_query/join_builder'
require 'arel/nodes/postgresql'

module ActiveRecord
  module HierarchicalQuery
    class Query
      # @api private
      ORDERING_COLUMN_NAME = '__order_column'.freeze

      # @api private
      attr_reader :klass,
                  :start_with_value,
                  :connect_by_value,
                  :child_scope_value,
                  :limit_value,
                  :offset_value,
                  :order_values,
                  :nocycle_value,
                  :distinct_value

      # @api private
      CHILD_SCOPE_METHODS = :where, :joins, :group, :having, :bind, :reorder

      def initialize(klass)
        @klass = klass

        # start with :all
        @start_with_value = klass.__send__(HierarchicalQuery::DELEGATOR_SCOPE)
        @connect_by_value = nil
        @child_scope_value = klass.__send__(HierarchicalQuery::DELEGATOR_SCOPE)
        @limit_value = nil
        @offset_value = nil
        @nocycle_value = false
        @order_values = []
        @distinct_value = false
      end

      # Specify root scope of the hierarchy.
      #
      # @example When scope given
      #   MyModel.join_recursive do |hierarchy|
      #     hierarchy.start_with(MyModel.where(parent_id: nil))
      #              .connect_by(id: :parent_id)
      #   end
      #
      # @example When Hash given
      #   MyModel.join_recursive do |hierarchy|
      #     hierarchy.start_with(parent_id: nil)
      #              .connect_by(id: :parent_id)
      #   end
      #
      # @example When String given
      #    MyModel.join_recursive do |hierarchy|
      #      hierararchy.start_with('parent_id = ?', 1)
      #                 .connect_by(id: :parent_id)
      #    end
      #
      # @example When block given
      #   MyModel.join_recursive do |hierarchy|
      #     hierarchy.start_with { |root| root.where(parent_id: nil) }
      #              .connect_by(id: :parent_id)
      #   end
      #
      # @example When block with arity=0 given
      #   MyModel.join_recursive do |hierarchy|
      #     hierarchy.start_with { where(parent_id: nil) }
      #              .connect_by(id: :parent_id)
      #   end
      #
      # @example Specify columns for root relation (PostgreSQL-specific)
      #   MyModel.join_recursive do |hierarchy|
      #     hierarchy.start_with { select('ARRAY[id] AS _path') }
      #              .connect_by(id: :parent_id)
      #              .select('_path || id', start_with: false) # `start_with: false` tells not to include this expression into START WITH clause
      #   end
      #
      # @param [ActiveRecord::Relation, Hash, String, nil] scope root scope (optional).
      # @return [ActiveRecord::HierarchicalQuery::Query] self
      def start_with(scope = nil, *arguments, &block)
        raise ArgumentError, 'START WITH: scope or block expected, none given' unless scope || block

        case scope
          when Hash, String
            @start_with_value = klass.where(scope, *arguments)

          when ActiveRecord::Relation
            @start_with_value = scope

          else
            # do nothing if something weird given
        end

        if block
          object = @start_with_value || @klass

          @start_with_value = if block.arity == 0
            object.instance_eval(&block)
          else
            block.call(object)
          end
        end

        self
      end

      # Specify relationship between parent rows and child rows of the
      # hierarchy. It can be specified with Hash where keys are parent columns
      # names and values are child columns names, or with block (see example below).
      #
      # @example Specify relationship with Hash (traverse descendants)
      #   MyModel.join_recursive do |hierarchy|
      #     # join child rows with condition `parent.id = child.parent_id`
      #     hierarchy.connect_by(id: :parent_id)
      #   end
      #
      # @example Specify relationship with block (traverse descendants)
      #   MyModel.join_recursive do |hierarchy|
      #     hierarchy.connect_by { |parent, child| parent[:id].eq(child[:parent_id]) }
      #   end
      #
      # @param [Hash, nil] conditions (optional) relationship between parent rows and
      #   child rows map, where keys are parent columns names and values are child columns names.
      # @yield [parent, child] Yields both parent and child tables.
      # @yieldparam [Arel::Table] parent parent rows table instance.
      # @yieldparam [Arel::Table] child child rows table instance.
      # @yieldreturn [Arel::Nodes::Node] relationship condition expressed as Arel node.
      # @return [ActiveRecord::HierarchicalQuery::Query] self
      def connect_by(conditions = nil, &block)
        # convert hash to block which returns Arel node
        if conditions
          block = conditions_to_proc(conditions)
        end

        raise ArgumentError, 'CONNECT BY: Conditions hash or block expected, none given' unless block

        @connect_by_value = block

        self
      end

      # Specify which columns should be selected in addition to primary key,
      # CONNECT BY columns and ORDER SIBLINGS columns.
      #
      # @param [Array<Symbol, String, Arel::Attributes::Attribute, Arel::Nodes::Node>] columns
      # @option columns [true, false] :start_with include given columns to START WITH clause (true by default)
      # @return [ActiveRecord::HierarchicalQuery::Query] self
      def select(*columns)
        options = columns.extract_options!

        columns = columns.flatten.map do |column|
          column.is_a?(Symbol) ? table[column] : column
        end

        # TODO: detect if column already present in START WITH clause and skip it
        if options.fetch(:start_with, true)
          start_with { |scope| scope.select(columns) }
        end

        @child_scope_value = @child_scope_value.select(columns)

        self
      end

      # Generate methods that apply filters to child scope, such as
      # +where+ or +group+.
      #
      # @example Filter child nodes by certain condition
      #   MyModel.join_recursive do |hierarchy|
      #     hierarchy.where('depth < 5')
      #   end
      #
      # @!method where(*conditions)
      # @!method joins(*tables)
      # @!method group(*values)
      # @!method having(*conditions)
      # @!method bind(value)
      # @!method reorder(value)
      CHILD_SCOPE_METHODS.each do |method|
        define_method(method) do |*args|
          @child_scope_value = @child_scope_value.public_send(method, *args)

          self
        end
      end

      # Specifies a limit for the number of records to retrieve.
      #
      # @param [Fixnum] value
      # @return [ActiveRecord::HierarchicalQuery::Query] self
      def limit(value)
        @limit_value = value

        self
      end

      # Specifies the number of rows to skip before returning row
      #
      # @param [Fixnum] value
      # @return [ActiveRecord::HierarchicalQuery::Query] self
      def offset(value)
        @offset_value = value

        self
      end

      # Specifies hierarchical order of the recursive query results.
      #
      # @example
      #   MyModel.join_recursive do |hierarchy|
      #     hierarchy.connect_by(id: :parent_id)
      #              .order_siblings(:name)
      #   end
      #
      # @example
      #   MyModel.join_recursive do |hierarchy|
      #     hierarchy.connect_by(id: :parent_id)
      #              .order_siblings('name DESC, created_at ASC')
      #   end
      #
      # @param [<Symbol, String, Arel::Nodes::Node, Arel::Attributes::Attribute>] columns
      # @return [ActiveRecord::HierarchicalQuery::Query] self
      def order_siblings(*columns)
        @order_values += columns

        self
      end
      alias_method :order, :order_siblings

      # Turn on/off cycles detection. This option can prevent
      # endless loops if your tree could contain cycles.
      #
      # @param [true, false] value
      # @return [ActiveRecord::HierarchicalQuery::Query] self
      def nocycle(value = true)
        @nocycle_value = value
        self
      end

      # Returns object representing parent rows table,
      # so it could be used in complex WHEREs.
      #
      # @example
      #   MyModel.join_recursive do |hierarchy|
      #     hierarchy.connect_by(id: :parent_id)
      #              .start_with(parent_id: nil) { select(:depth) }
      #              .select(hierarchy.table[:depth])
      #              .where(hierarchy.prior[:depth].lteq 1)
      #   end
      #
      # @return [Arel::Table]
      def prior
        @recursive_table ||= Arel::Table.new("#{normalized_table_name}__recursive")
      end
      alias_method :previous, :prior
      alias_method :recursive_table, :prior

      # Returns object representing child rows table,
      # so it could be used in complex WHEREs.
      #
      # @example
      #   MyModel.join_recursive do |hierarchy|
      #     hierarchy.connect_by(id: :parent_id)
      #              .start_with(parent_id: nil) { select(:depth) }
      #              .select(hierarchy.table[:depth])
      #              .where(hierarchy.prior[:depth].lteq 1)
      #   end
      def table
        @klass.arel_table
      end

      # Turn on select distinct option in the CTE.
      #
      # @return [ActiveRecord::HierarchicalQuery::Query] self
      def distinct
        @distinct_value = true
        self
      end

      # @return [Arel::Nodes::Node]
      # @api private
      def join_conditions
        connect_by_value.call(recursive_table, table)
      end

      # @return [ActiveRecord::HierarchicalQuery::Orderings]
      # @api private
      def orderings
        @orderings ||= Orderings.new(order_values, table)
      end

      # @api private
      def ordering_column_name
        ORDERING_COLUMN_NAME
      end

      # Builds recursive query and joins it to given +relation+.
      #
      # @api private
      # @param [ActiveRecord::Relation] relation
      # @param [Hash] join_options
      # @option join_options [#to_s] :as joined table alias
      # @api private
      def join_to(relation, join_options = {})
        raise 'Recursive query requires CONNECT BY clause, please use #connect_by method' unless
            connect_by_value

        table_alias = join_options.fetch(:as, "#{normalized_table_name}__recursive")

        JoinBuilder.new(self, relation, table_alias, join_options).build
      end

      private
      # converts conditions given as a hash to proc
      def conditions_to_proc(conditions)
        proc do |parent, child|
          conditions.map do |parent_expression, child_expression|
            parent_expression = parent[parent_expression] if parent_expression.is_a?(Symbol)
            child_expression = child[child_expression] if child_expression.is_a?(Symbol)

            Arel::Nodes::Equality.new(parent_expression, child_expression)
          end.reduce(:and)
        end
      end

      def normalized_table_name
        table.name.gsub('.', '_')
      end
    end # class Builder
  end # module HierarchicalQuery
end # module ActiveRecord
