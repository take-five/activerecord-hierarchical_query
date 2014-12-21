ActiveRecord::Migration.verbose = false

ActiveRecord::Schema.define(version: 0) do
  create_table :categories, force: true do |t|
    t.column :parent_id, :integer
    t.column :name, :string
    t.column :depth, :integer
    t.column :position, :integer
  end
end