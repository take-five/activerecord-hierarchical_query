# coding: utf-8

require 'active_record/hierarchical_query/adapters'

module ActiveRecord
  module HierarchicalQuery
    class Builder
      # @api private
      attr_reader :klass,
                  :start_with_value,
                  :connect_by_value,
                  :child_scope_value,
                  :limit_value,
                  :offset_value,
                  :order_values

      # @api private
      CHILD_SCOPE_METHODS = :select, :where, :joins, :group, :having

      def initialize(klass)
        @klass = klass
        @adapter = Adapters.lookup(@klass).new(self)

        @start_with_value = nil
        @connect_by_value = nil
        @child_scope_value = klass
        @limit_value = nil
        @offset_value = nil
        @order_values = []
      end

      # Specify root scope of the hierarchy.
      #
      # @example When scope given
      #   MyModel.join_recursive do |hierarchy|
      #     hierarchy.start_with(MyModel.where(:parent_id => nil))
      #              .connect_by(:id => :parent_id)
      #   end
      #
      # @example When Hash given
      #   MyModel.join_recursive do |hierarchy|
      #     hierarchy.start_with(:parent_id => nil)
      #              .connect_by(:id => :parent_id)
      #   end
      #
      # @example When block given
      #   MyModel.join_recursive do |hierarchy|
      #     hierarchy.start_with { |root| root.where(:parent_id => nil) }
      #              .connect_by(:id => :parent_id)
      #   end
      #
      # @example When block with arity=0 given
      #   MyModel.join_recursive do |hierarchy|
      #     hierarchy.start_with { where(:parent_id => nil) }
      #              .connect_by(:id => :parent_id)
      #   end
      #
      # @example Specify columns for root relation (PostgreSQL-specific)
      #   MyModel.join_recursive do |hierarchy|
      #     hierarchy.start_with { select('ARRAY[id] AS _path') }
      #              .connect_by(:id => :parent_id)
      #              .select('_path || id')
      #   end
      #
      # @param [ActiveRecord::Relation, Hash, nil] scope root scope (optional).
      # @return [ActiveRecord::HierarchicalQuery::Builder] self
      def start_with(scope = nil, &block)
        raise ArgumentError, 'START WITH: scope or block expected, none given' unless scope || block

        @start_with_value = case scope
          when Hash
            klass.where(scope)

          when ActiveRecord::Relation
            scope

          else
            nil
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
      #     hierarchy.connect_by(:id => :parent_id)
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
      # @return [ActiveRecord::HierarchicalQuery::Builder] self
      def connect_by(conditions = nil, &block)
        # convert hash to block which returns Arel node
        if conditions
          block = conditions_to_proc(conditions)
        end

        raise ArgumentError, 'CONNECT BY: Conditions hash or block expected, none given' unless block

        @connect_by_value = block

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
      # @!method select(*columns)
      # @!method joins(*tables)
      # @!method group(*values)
      # @!method having(*conditions)
      CHILD_SCOPE_METHODS.each do |method|
        define_method(method) do |*args|
          @child_scope_value = @child_scope_value.public_send(method, *args)

          self
        end
      end

      # Specifies a limit for the number of records to retrieve.
      #
      # @param [Fixnum] value
      # @return [ActiveRecord::HierarchicalQuery::Builder] self
      def limit(value)
        @limit_value = value

        self
      end

      # Specifies the number of rows to skip before returning row
      #
      # @param [Fixnum] value
      # @return [ActiveRecord::HierarchicalQuery::Builder] self
      def offset(value)
        @offset_value = value

        self
      end

      # Specifies hierarchical order of the recursive query results.
      #
      # @example
      #   MyModel.join_recursive do |hierarchy|
      #     hierarchy.connect_by(:id => :parent_id)
      #              .order_siblings(:name)
      #   end
      #
      # @example
      #   MyModel.join_recursive do |hierarchy|
      #     hierarchy.connect_by(:id => :parent_id)
      #              .order_siblings('name DESC, created_at ASC')
      #   end
      #
      # @param [<Symbol, String, Arel::Nodes::Node, Arel::Attributes::Attribute>] columns
      # @return [ActiveRecord::HierarchicalQuery::Builder] self
      def order_siblings(*columns)
        @order_values += columns

        self
      end
      alias_method :order, :order_siblings

      # Returns object representing parent rows table,
      # so it could be used in complex WHEREs.
      #
      # @example
      #   MyModel.join_recursive do |hierarchy|
      #     hierarchy.connect_by(:id => :parent_id)
      #              .start_with(:parent_id => nil) { select(:depth) }
      #              .select(hierarchy.table[:depth])
      #              .where(hierarchy.prior[:depth].lteq 1)
      #   end
      #
      # @return [Arel::Table]
      def prior
        @adapter.prior
      end
      alias_method :previous, :prior

      # Returns object representing child rows table,
      # so it could be used in complex WHEREs.
      #
      # @example
      #   MyModel.join_recursive do |hierarchy|
      #     hierarchy.connect_by(:id => :parent_id)
      #              .start_with(:parent_id => nil) { select(:depth) }
      #              .select(hierarchy.table[:depth])
      #              .where(hierarchy.prior[:depth].lteq 1)
      #   end
      def table
        @klass.arel_table
      end

      # Builds recursive query and joins it to given +relation+.
      #
      # @api private
      # @param [ActiveRecord::Relation] relation
      def join_to(relation)
        raise 'Recursive query requires CONNECT BY clause, please use #connect_by method' unless
            connect_by_value

        @adapter.build_join(relation)
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
    end # class Builder
  end # module HierarchicalQuery
end # module ActiveRecord