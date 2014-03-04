require 'spec_helper'

describe ActiveRecord::HierarchicalQuery::Builder do
  let(:builder) { described_class.new(Category) }

  before { builder.connect_by(:id => :parent_id).start_with { where(:parent_id => nil) }.order_siblings('name  DESC, x ASc', :gas => :desc) }

  it { puts builder.build_relation.to_sql }
  it { puts builder.build_join(Category.all).to_sql }
end