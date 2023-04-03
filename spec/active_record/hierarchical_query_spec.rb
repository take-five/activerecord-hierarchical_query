require 'spec_helper'

describe ActiveRecord::HierarchicalQuery do
  let(:klass) { Category }

  let(:trait_id) { 'trait' }
  let!(:root) { klass.create(trait_id: trait_id) }
  let!(:child_1) { klass.create(parent: root, trait_id: trait_id) }
  let!(:child_2) { klass.create(parent: child_1, trait_id: trait_id) }
  let!(:child_3) { klass.create(parent: child_1, trait_id: trait_id) }
  let!(:child_4) { klass.create(parent: root, trait_id: trait_id) }
  let!(:child_5) { klass.create(parent: child_4, trait_id: trait_id) }

  describe '#join_recursive' do
    describe 'UNION clause' do
      let(:options) { {} }
      subject { klass.join_recursive(options) { connect_by(id: :parent_id) }.to_sql }

      it 'defaults to UNION ALL' do
        expect(subject).to include('UNION ALL')
      end

      context 'specifying DISTINCT union type' do
        let(:options) { { union_type: :distinct } }

        it 'uses UNION DISTINCT' do
          expect(subject).to include('UNION DISTINCT')
          expect(subject).to_not include('UNION ALL')
        end
      end

      context 'specifying ALL union type' do
        let(:options) { { union_type: :all } }

        it 'uses UNION ALL' do
          expect(subject).to include('UNION ALL')
          expect(subject).to_not include('UNION DISTINCT')
        end
      end
    end

    describe 'CONNECT BY clause' do
      it 'throws error if CONNECT BY clause not specified' do
        expect {
          klass.join_recursive {}
        }.to raise_error /CONNECT BY clause/
      end

      it 'joins parent and child rows by hash map' do
        expect(
          klass.join_recursive { connect_by(id: :parent_id) }
        ).to include root, child_1, child_2, child_3, child_4, child_5
      end

      it 'joins parent and child rows by block' do
        expect(
          klass.join_recursive do
            connect_by { |parent, child| parent[:id].eq child[:parent_id] }
          end
        ).to include root, child_1, child_2, child_3, child_4, child_5
      end

      it 'handles Arel::Nodes::As name delegation' do
        expected_array = \
        klass.join_recursive do
          connect_by { |parent, child| parent[:id].eq child[:parent_id] }
        end

        expect(
          child_5.alias_node_query
        ).to match_array expected_array
      end

    end

    describe 'START WITH clause' do
      def assert_start_with(&block)
        expect(
          klass.join_recursive do |b|
            b.connect_by(id: :parent_id).instance_eval(&block)
          end
        ).to match_array [root, child_1, child_2, child_3, child_4, child_5]
      end

      it 'filters rows in non-recursive term by hash' do
        assert_start_with { start_with(parent_id: nil) }
      end

      it 'filters rows in non-recursive term by block with arity > 0' do
        assert_start_with { start_with { |root| root.where(parent_id: nil) } }
      end

      it 'filters rows in non-recursive term by block with arity = 0' do
        assert_start_with { start_with { where(parent_id: nil) } }
      end

      it 'filters rows in non-recursive term by scope' do
        assert_start_with { start_with(klass.where(parent_id: nil)) }
      end
    end

    describe 'ORDER SIBLINGS BY clause' do
      def assert_ordered_by_name_desc(&block)
        expect(
          klass.join_recursive do |b|
            b.connect_by(id: :parent_id).start_with(parent_id: nil).instance_eval(&block)
          end
        ).to eq [root, child_4, child_5, child_1, child_3, child_2]
      end

      def assert_ordered_by_name_asc(&block)
        expect(
            klass.join_recursive do |b|
              b.connect_by(id: :parent_id).start_with(parent_id: nil).instance_eval(&block)
            end
        ).to eq [root, child_1, child_2, child_3, child_4, child_5]
      end

      it 'orders rows by Hash' do
        assert_ordered_by_name_desc { order_siblings(name: :desc) }
      end

      it 'orders rows by Arel::Nodes::Ordering' do
        assert_ordered_by_name_desc { order_siblings(table[:name].desc) }
      end

      it 'orders rows by Arel::Nodes::Node' do
        assert_ordered_by_name_asc { order_siblings(table[:name]) }
      end

      it 'throws error when something weird given' do
        expect {
          klass.join_recursive { connect_by(id: :parent_id).order_siblings(1) }
        }.to raise_error /ORDER BY SIBLINGS/
      end

      context 'when one attribute given and this attribute support natural sorting' do
        let(:relation) do
          klass.join_recursive do
            connect_by(id: :parent_id).
            start_with(parent_id: nil).
            order_siblings(:position)
          end
        end

        it 'orders rows by given attribute' do
          expect(relation).to eq [root, child_1, child_2, child_3, child_4, child_5]
          expect(relation.to_sql).not_to match /row_number/i
        end
      end

      context 'when ordering by String' do
        it 'orders rows by one column' do
          assert_ordered_by_name_desc { order_siblings('name desc') }
          assert_ordered_by_name_asc { order_siblings('name asc') }
        end

        it 'orders rows by multiple columns' do
          root.update!(name: "Root", trait_id: "a")
          child_2.update!(name: 'Same Name', trait_id: 'a')
          child_3.update!(name: 'Same Name', trait_id: 'b')
          root2 = klass.create(name: "Root", trait_id: "b")

          expect(
            klass.join_recursive do |b|
              b.connect_by(id: :parent_id).start_with(parent_id: nil).order_siblings('name asc, trait_id desc')
            end
          ).to eq [root2, root, child_1, child_3, child_2, child_4, child_5]
        end
      end
    end

    describe 'LIMIT and OFFSET clauses' do
      let(:ordered_nodes) { [root, child_1, child_2, child_3, child_4, child_5] }

      it 'limits all rows' do
        expect(
          klass.join_recursive do
            connect_by(id: :parent_id).
            start_with(parent_id: nil).
            limit(2).
            offset(2)
          end.size
        ).to eq 2
      end

      it 'limits all rows if ordering given' do
        expect(
            klass.join_recursive do
              connect_by(id: :parent_id).
              start_with(parent_id: nil).
              order_siblings(:name).
              limit(2).
              offset(2)
            end
        ).to eq ordered_nodes[2...4]
      end
    end

    describe 'WHERE clause' do
      it 'filters child rows' do
        expect(
          klass.join_recursive do
            connect_by(id: :parent_id).
            start_with(parent_id: nil).
            where('depth < ?', 2)
          end
        ).to match_array [root, child_1, child_4]
      end

      it 'allows to use PRIOR relation' do
        expect(
          klass.join_recursive do |b|
            b.connect_by(id: :parent_id)
             .start_with(parent_id: nil)
             .select(:depth)
             .where(b.prior[:depth].lt(1))
          end
        ).to match_array [root, child_1, child_4]
      end
    end

    describe 'SELECT clause' do
      it 'adds column to both recursive and non-recursive term' do
        expect(
          klass.join_recursive(as: 'categories_r') do
            connect_by(id: :parent_id).
            start_with(parent_id: nil).
            select(:depth)
          end.where('categories_r.depth = 0')
        ).to eq [root]
      end
    end

    describe 'NOCYCLE clause' do
      before { klass.where(id: child_4.id).update_all(parent_id: child_5.id) }

      it 'prevents recursive query from endless loops' do
        expect(
          klass.join_recursive do |query|
            query.start_with(id: child_4.id)
                 .connect_by(id: :parent_id)
                 .nocycle
          end
        ).to match_array [child_4, child_5]
      end
    end
  end

  describe '#join_recursive options' do
    describe ':as option' do
      it 'builds a join with specified alias' do
        expect(
          klass.join_recursive(as: 'my_table') { connect_by(id: :parent_id) }.to_sql
        ).to match /my_table/
      end
    end

    describe ':foreign_key' do
      it 'uses described foreign_key when joining table to recursive view' do
        expect(
          klass.join_recursive(foreign_key: 'some_column') { connect_by(id: :parent_id) }.to_sql
        ).to match /categories\"\.\"id\" = \"categories__recursive\"\.\"some_column/
      end
    end

    describe ':outer_join_hierarchical' do
      subject { klass.join_recursive(outer_join_hierarchical: value) { connect_by(id: :parent_id) }.to_sql }

      let(:value) { true }
      let(:inner_join) {
        /INNER JOIN \(WITH RECURSIVE \"categories__recursive\"/
      }

      it 'builds an outer join' do
        expect(subject).to match /LEFT OUTER JOIN \(WITH RECURSIVE \"categories__recursive\"/
      end

      context 'value is false' do
        let(:value) { false }

        it 'builds an inner join' do
          expect(subject).to match inner_join
        end
      end

      context 'value is a string' do
        let(:value) { 'foo' }

        it 'builds an inner join' do
          expect(subject).to match inner_join
        end
      end

      context 'key is absent' do
        subject { klass.join_recursive { connect_by(id: :parent_id) }.to_sql }

        it 'builds an inner join' do
          expect(subject).to match inner_join
        end
      end
    end
  end

  describe ':distinct query method' do
    subject { klass.join_recursive { connect_by(id: :parent_id).distinct }.to_sql }

    let(:select) {
      /SELECT \"categories__recursive\"/
    }

    it 'selects using a distinct option after joining table to recursive view' do
      expect(subject).to match /SELECT DISTINCT \"categories__recursive\"/
    end

    context 'distinct method is absent' do
      subject { klass.join_recursive { connect_by(id: :parent_id) }.to_sql }

      it 'selects without using a distinct' do
        expect(subject).to match select
      end
    end
  end

  describe 'Testing bind variables' do
    let!(:article) { Article.create!(category: child_2, title: 'Alpha') }

    let(:subquery) do
      klass.join_recursive do |query|
        query.
          start_with(trait_id: trait_id, parent_id: child_1.id).
          connect_by(id: :parent_id).
          where(trait_id: trait_id)
      end
    end

    let(:outer_query) do
      Article.where(category_id: subquery, title: 'Alpha')
    end

    subject(:result) { outer_query.to_a }

    it 'returns result without throwing an error' do
      expect(result).to include(article)
    end
  end

  describe 'Models with default scope' do
    let!(:scoped_root) { ModelWithDefaultScope.create!(name: '9. Root') }
    let!(:scoped_child_1) { ModelWithDefaultScope.create!(name: '8. Child', parent: scoped_root) }
    let!(:scoped_child_2) { ModelWithDefaultScope.create!(name: '7. Child', parent: scoped_root) }

    subject(:result) {
      ModelWithDefaultScope.join_recursive do |query|
        query
          .connect_by(id: :parent_id)
          .start_with(id: scoped_root.id)
      end
    }

    it 'applies default scope to outer query without affecting recursive terms' do
      expect(result).to eq [scoped_child_2, scoped_child_1, scoped_root]
    end
  end
end
