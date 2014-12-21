# ActiveRecord::HierarchicalQuery

[![Build Status](https://travis-ci.org/take-five/activerecord-hierarchical_query.png?branch=master)](https://travis-ci.org/take-five/activerecord-hierarchical_query)
[![Code Climate](https://codeclimate.com/github/take-five/activerecord-hierarchical_query.png)](https://codeclimate.com/github/take-five/activerecord-hierarchical_query)
[![Coverage Status](https://coveralls.io/repos/take-five/activerecord-hierarchical_query/badge.png)](https://coveralls.io/r/take-five/activerecord-hierarchical_query)
[![Dependency Status](https://gemnasium.com/take-five/activerecord-hierarchical_query.png)](https://gemnasium.com/take-five/activerecord-hierarchical_query)
[![Gem Version](https://badge.fury.io/rb/activerecord-hierarchical_query.png)](http://badge.fury.io/rb/activerecord-hierarchical_query)

Create hierarchical queries using simple DSL, recursively traverse trees using single SQL query.

If a table contains hierarchical data, then you can select rows in hierarchical order using hierarchical query builder.

### Traverse trees

Let's say you've got an ActiveRecord model `Category` that related to itself:

```ruby
class Category < ActiveRecord::Base
  belongs_to :parent, class_name: 'Category'
  has_many :children, foreign_key: :parent_id, class_name: 'Category'
end

# Table definition
# create_table :categories do |t|
#   t.integer :parent_id
#   t.string :name
# end
```

### Traverse descendants

```ruby
Category.join_recursive do |query|
  query.start_with(parent_id: nil)
       .connect_by(id: :parent_id)
       .order_siblings(:name)
end # returns ActiveRecord::Relation instance
```

### Traverse ancestors

```ruby
Category.join_recursive do |query|
  query.start_with(id: 42)
       .connect_by(parent_id: :id)
end
```

### Show breadcrumbs using single SQL query

```ruby
records = Category.join_recursive do |query|
  query
    # assume that deepest node has depth=0
    .start_with(id: 42) { select('0 depth') }
    # for each ancestor decrease depth by 1, do not apply
    # following expression to first level of hierarchy
    .select(query.prior[:depth] - 1, start_with: false)
    .connect_by(parent_id: :id)
end.order('depth ASC')

# returned value is just regular ActiveRecord::Relation instance, so you can use its methods
crumbs = records.pluck(:name).join(' / ')
```

## Requirements

* ActiveRecord >= 3.1.0
* PostgreSQL >= 8.4

## Installation

Add this line to your application's Gemfile:

    gem 'activerecord-hierarchical_query'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install activerecord-hierarchical_query

## Usage

Let's say you've got an ActiveRecord model `Category` with attributes `id`, `parent_id`
and `name`. You can traverse nodes recursively starting from root rows connected by
`parent_id` column ordered by `name`:

```ruby
Category.join_recursive do
  start_with(parent_id: nil).
  connect_by(id: :parent_id).
  order_siblings(:name)
end
```

Hierarchical queries consist of these important clauses:

* **START WITH** clause

  This clause specifies the root row(s) of the hierarchy.
* **CONNECT BY** clause

  This clause specifies relationship between parent rows and child rows of the hierarchy.
* **ORDER SIBLINGS** clause

  This clause specifies an order of rows in which they appear on each hierarchy level.

These terms are borrowed from [Oracle hierarchical queries syntax](http://docs.oracle.com/cd/B19306_01/server.102/b14200/queries003.htm).

Hierarchical queries are processed as follows:

* First, root rows are selected -- those rows that satisfy `START WITH` condition in
  order specified by `ORDER SIBLINGS` clause. In example above it's specified by
  statements `query.start_with(parent_id: nil)` and `query.order_siblings(:name)`.
* Second, child rows for each root rows are selected. Each child row must satisfy
  condition specified by `CONNECT BY` clause with respect to one of the root rows
  (`query.connect_by(id: :parent_id)` in example above). Order of child rows is
  also specified by `ORDER SIBLINGS` clause.
* Successive generations of child rows are selected with respect to `CONNECT BY` clause.
  First the children of each row selected in step 2 selected, then the children of those
  children and so on.

### START WITH

This clause is specified by `start_with` method:

```ruby
Category.join_recursive { start_with(parent_id: nil) }
Category.join_recursive { start_with { where(parent_id: nil) } }
Category.join_recursive { start_with { |root_rows| root_rows.where(parent_id: nil) } }
```

All of these statements are equivalent.

### CONNECT BY

This clause is necessary and specified by `connect_by` method:

```ruby
# join parent table ID columns and child table PARENT_ID column
Category.join_recursive { connect_by(id: :parent_id) }

# you can use block to build complex JOIN conditions
Category.join_recursive do
  connect_by do |parent_table, child_table|
    parent_table[:id].eq child_table[:parent_id]
  end
end
```

### ORDER SIBLINGS

You can specify order in which rows on each hierarchy level should appear:

```ruby
Category.join_recursive { order_siblings(:name) }

# you can reverse order
Category.join_recursive { order_siblings(name: :desc) }

# arbitrary strings and Arel nodes are allowed also
Category.join_recursive { order_siblings('name ASC') }
Category.join_recursive { |query| query.order_siblings(query.table[:name].asc) }
```

### WHERE conditions

You can filter rows on each hierarchy level by applying `WHERE` conditions:

```ruby
Category.join_recursive do
  connect_by(id: :parent_id).where('name LIKE ?', 'ruby %')
end
```

You can even refer to parent table, just don't forget to include columns in `SELECT` clause!

```ruby
Category.join_recursive do |query|
  query.connect_by(id: :parent_id)
       .select(:name).
       .where(query.prior[:name].matches('ruby %'))
end
```

Or, if Arel semantics does not fit your needs:

```ruby
Category.join_recursive do |query|
  query.connect_by(id: :parent_id)
       .where("#{query.prior.name}.name LIKE ?", 'ruby %')
end
```

### NOCYCLE

Recursive query will loop if hierarchy contains cycles (your graph is not acyclic).
`NOCYCLE` clause, which is turned off by default, could prevent it.

Loop example:

```ruby
node_1 = Category.create
node_2 = Category.create(parent: node_1)

node_1.parent = node_2
node_1.save
```

`node_1` and `node_2` now link to each other, so following query will never end:

```ruby
Category.join_recursive do |query|
  query.connect_by(id: :parent_id)
       .start_with(id: node_1.id)
end
```

`#nocycle` method will prevent endless loop:

```ruby
Category.join_recursive do |query|
  query.connect_by(id: :parent_id)
       .start_with(id: node_1.id)
       .nocycle
end
```

## Generated SQL queries

Under the hood this extensions builds `INNER JOIN` to recursive subquery.

For example, this piece of code

```ruby
Category.join_recursive do |query|
  query.start_with(parent_id: nil) { select('0 LEVEL') }
       .connect_by(id: :parent_id)
       .select(:depth)
       .select(query.prior[:LEVEL] + 1, start_with: false)
       .where(query.prior[:depth].lteq(5))
       .order_siblings(:position)
       .nocycle
end
```

would generate following SQL (if PostgreSQL used):

```sql
SELECT "categories".*
FROM "categories" INNER JOIN (
    WITH RECURSIVE "categories__recursive" AS (
        SELECT depth,
               0 LEVEL,
               "categories"."id",
               "categories"."parent_id",
               ARRAY["categories"."position"] AS __order_column,
               ARRAY["categories"."id"] AS __path
        FROM "categories"
        WHERE "categories"."parent_id" IS NULL

        UNION ALL

        SELECT "categories"."depth",
               "categories__recursive"."LEVEL" + 1,
               "categories"."id",
               "categories"."parent_id",
               "categories__recursive"."__order_column" || "categories"."position",
               "categories__recursive"."__path" || "categories"."id"
        FROM "categories" INNER JOIN
             "categories__recursive" ON "categories__recursive"."id" = "categories"."parent_id"
        WHERE ("categories__recursive"."depth" <= 5) AND
              NOT ("categories"."id" = ANY("categories__recursive"."__path"))
    )
    SELECT "categories__recursive".* FROM "categories__recursive"
) AS "categories__recursive" ON "categories"."id" = "categories__recursive"."id"
ORDER BY "categories__recursive"."__order_column" ASC
```

## Related resources

* [About hierarchical queries (Wikipedia)](http://en.wikipedia.org/wiki/Hierarchical_and_recursive_queries_in_SQL)
* [Hierarchical queries in Oracle](http://docs.oracle.com/cd/B19306_01/server.102/b14200/queries003.htm)
* [Recursive queries in PostgreSQL](http://www.postgresql.org/docs/9.3/static/queries-with.html)
* [Using Recursive SQL with ActiveRecord trees](http://hashrocket.com/blog/posts/recursive-sql-in-activerecord)

## Contributing

1. Fork it ( http://github.com/take-five/activerecord-hierarchical_query/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
