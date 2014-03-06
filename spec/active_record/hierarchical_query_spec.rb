require 'spec_helper'

describe ActiveRecord::HierarchicalQuery do
  let(:klass) { Category }

  let!(:root) { klass.create }
  let!(:child_1) { klass.create(:parent => root) }
  let!(:child_2) { klass.create(:parent => child_1) }
  let!(:child_3) { klass.create(:parent => child_1) }
  let!(:child_4) { klass.create(:parent => root) }
  let!(:child_5) { klass.create(:parent => child_4) }

  describe '#join_recursive' do
    describe 'CONNECT BY clause' do
      it 'throws error if CONNECT BY clause not specified' do
        expect {
          klass.join_recursive {}
        }.to raise_error /CONNECT BY clause/
      end

      it 'joins parent and child rows by hash map' do
        expect(
          klass.join_recursive { |b| b.connect_by(:id => :parent_id) }
        ).to include root, child_1, child_2, child_3, child_4, child_5
      end

      it 'joins parent and child rows by block' do
        expect(
          klass.join_recursive do |b|
            b.connect_by { |parent, child| parent[:id].eq child[:parent_id] }
          end
        ).to include root, child_1, child_2, child_3, child_4, child_5
      end
    end

    describe 'START WITH clause' do
      def assert_start_with
        expect(
          klass.join_recursive do |b|
            yield b.connect_by(:id => :parent_id)
          end
        ).to match_array [root, child_1, child_2, child_3, child_4, child_5]
      end

      it 'filters rows in non-recursive term by hash' do
        assert_start_with { |b| b.start_with(:parent_id => nil) }
      end

      it 'filters rows in non-recursive term by block with arity > 0' do
        assert_start_with { |b| b.start_with { |root| root.where(:parent_id => nil) } }
      end

      it 'filters rows in non-recursive term by block with arity = 0' do
        assert_start_with { |b| b.start_with { where(:parent_id => nil) } }
      end

      it 'filters rows in non-recursive term by scope' do
        assert_start_with { |b| b.start_with(klass.where(:parent_id => nil)) }
      end
    end

    describe 'ORDER SIBLINGS BY clause' do
      def assert_ordered_by_name_desc(&block)
        expect(
          klass.join_recursive do |b|
            b.connect_by(:id => :parent_id).start_with(:parent_id => nil).instance_eval(&block)
          end
        ).to eq [root, child_4, child_5, child_1, child_3, child_2]
      end

      def assert_ordered_by_name_asc(&block)
        expect(
            klass.join_recursive do |b|
              b.connect_by(:id => :parent_id).start_with(:parent_id => nil).instance_eval(&block)
            end
        ).to eq [root, child_1, child_2, child_3, child_4, child_5]
      end

      it 'orders rows by Hash' do
        assert_ordered_by_name_desc { order_siblings(:name => :desc) }
      end

      it 'orders rows by String' do
        assert_ordered_by_name_desc { order_siblings('name desc') }
        assert_ordered_by_name_asc { order_siblings('name asc') }
      end

      it 'orders rows by Arel::Nodes::Ordering' do
        assert_ordered_by_name_desc { order_siblings(table[:name].desc) }
      end

      it 'orders rows by Arel::Nodes::Node' do
        assert_ordered_by_name_asc { order_siblings(table[:name]) }
      end

      it 'throws error when something weird given' do
        expect {
          klass.join_recursive do |b|
            b.connect_by(:id => :parent_id).order_siblings(1)
          end
        }.to raise_error /ORDER BY SIBLINGS/
      end
    end

    describe 'LIMIT and OFFSET clauses' do
      let(:ordered_nodes) { [root, child_1, child_2, child_3, child_4, child_5] }

      it 'limits all rows' do
        expect(
          klass.join_recursive do |b|
            b.connect_by(:id => :parent_id)
             .start_with(:parent_id => nil)
             .order_siblings(:name)
             .limit(2)
             .offset(2)
          end
        ).to eq ordered_nodes[2...4]
      end
    end

    describe 'WHERE clause' do
      it 'filters child rows' do
        expect(
          klass.join_recursive do |b|
            b.connect_by(:id => :parent_id)
             .start_with(:parent_id => nil)
             .where('depth < ?', 2)
          end
        ).to match_array [root, child_1, child_4]
      end

      it 'allows to use PRIOR relation' do
        expect(
          klass.join_recursive do |b|
            b.connect_by(:id => :parent_id)
             .start_with(:parent_id => nil) { select(:depth) }
             .select(b.table[:depth])
             .where(b.prior[:depth].lt(1))
          end
        ).to match_array [root, child_1, child_4]
      end
    end
  end
end