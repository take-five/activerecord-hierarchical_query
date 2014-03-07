# ActiveRecord::HierarchicalQuery [![Code Climate](https://codeclimate.com/github/take-five/activerecord-hierarchical_query.png)](https://codeclimate.com/github/take-five/activerecord-hierarchical_query)

Create hierarchical queries using simple DSL, recursively traverse trees using single SQL query.

If a table contains hierarchical data, then you can select rows in hierarchical order using hierarchical query builder.


### Traverse descendants

```ruby
Category.join_recursive do |query|
  query.start_with(:parent_id => nil)
       .connect_by(:id => :parent_id)
       .order_siblings(:name)
end
```

### Traverse ancestors

```ruby
Category.join_recursive do |query|
  query.start_with(:id => 42)
       .connect_by(:parent_id => :id)
end
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
Category.join_recursive do |query|
  query.start_with(:parent_id => nil)
       .connect_by(:id => :parent_id)
       .order_siblings(:name)
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
  statements `query.start_with(:parent_id => nil)` and `query.order_siblings(:name)`.
* Second, child rows for each root rows are selected. Each child row must satisfy
  condition specified by `CONNECT BY` clause with respect to one of the root rows
  (`query.connect_by(:id => :parent_id)` in example above). Order of child rows is
  also specified by `ORDER SIBLINGS` clause.
* Successive generations of child rows are selected with respect to `CONNECT BY` clause.
  First the children of each row selected in step 2 selected, then the children of those
  children and so on.

### START WITH

This clause is specified by `start_with` method:

```ruby
Category.join_recursive { |query| query.start_with(:parent_id => nil) }
Category.join_recursive { |query| query.start_with { where(:parent_id => nil) } }
Category.join_recursive { |query| query.start_with { |root_rows| root_rows.where(:parent_id => nil) } }
```

All of these statements are equivalent.

### CONNECT BY

This clause is necessary and specified by `connect_by` method:

```ruby
# join parent table ID columns and child table PARENT_ID column
Category.join_recursive { |query| query.connect_by(:id => :parent_id) }

# you can use block to build complex JOIN conditions
Category.join_recursive do |query|
  query.connect_by do |parent_table, child_table|
    parent_table[:id].eq child_table[:parent_id]
  end
end
```

### ORDER SIBLINGS

You can specify order in which rows on each hierarchy level should appear:

```ruby
Category.join_recursive { |query| query.order_siblings(:name) }

# you can reverse order
Category.join_recursive { |query| query.order_siblings(:name => :desc) }

# arbitrary strings and Arel nodes are allowed also
Category.join_recursive { |query| query.order_siblings('name ASC') }
Category.join_recursive { |query| query.order_siblings(query.table[:name].asc) }
```

### WHERE conditions

You can filter rows on each hierarchy level by applying `WHERE` conditions:

```ruby
Category.join_recursive do |query|
  query.connect_by(:id => :parent_id)
       .where('name LIKE ?', 'ruby %')
end
```

You can even refer to parent table!

```ruby
Category.join_recursive do |query|
  query.connect_by(:id => :parent_id)
       .where(query.prior[:name].matches('ruby %'))
end
```

Or, if Arel semantics does not fit your needs:

```ruby
Category.join_recursive do |query|
  query.connect_by(:id => :parent_id)
       .where("#{query.prior.name}.name LIKE ?", 'ruby %')
end
```

## Generated SQL queries

Under the hood this extensions builds `INNER JOIN` to recursive subquery.

For example, this piece of code

```ruby
Category.join_recursive do |query|
  query.start_with(:parent_id => nil) { select(:depth) }
       .connect_by(:id => :parent_id)
       .where(query.prior[:depth].lteq(5))
       .order_siblings(:position)
end
```

would generate following SQL (if PostgreSQL used):

```sql
SELECT "categories".*
FROM "categories" INNER JOIN (
    WITH RECURSIVE "categories__recursive" AS (
        SELECT depth,
               "categories"."id",
               "categories"."parent_id",
               ARRAY["categories"."position"] AS __order_column
        FROM "categories"
        WHERE "categories"."parent_id" IS NULL

        UNION ALL

        SELECT "categories"."depth",
               "categories"."id",
               "categories"."parent_id",
               "categories__recursive"."__order_column" || "categories"."position"
        FROM "categories" INNER JOIN
             "categories__recursive" ON "categories__recursive"."id" = "categories"."parent_id"
        WHERE ("categories__recursive"."depth" <= 5)
    )
    SELECT "categories__recursive".* FROM "categories__recursive"
) AS "categories__recursive" ON "categories"."id" = "categories__recursive"."id"
ORDER BY "categories__recursive"."__order_column" ASC
```


## Future plans

* Oracle support
* NOCYCLE filter

## Contributing

1. Fork it ( http://github.com/take-five/activerecord-hierarchical_query/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
