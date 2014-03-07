class Category < ActiveRecord::Base
  @@generator = Enumerator.new do |y|
    abc = ('a'..'z').to_a
    sequence = abc.product(abc, abc).map(&:join).to_enum

    loop do
      # category aaa
      # category aab
      # ...
      # category aaz
      # category aba
      # ...
      y << "category #{sequence.next}"
    end
  end

  belongs_to :parent, :class_name => 'Category'
  has_many :children, :class_name => 'Category'

  before_save :generate_name, :unless => :name?
  before_save :count_depth
  before_save :count_position

  def generate_name
    self.name = @@generator.next
  end

  def count_depth
    self.depth = ancestors.count
  end

  def count_position
    self.position = (self.class.where(:parent_id => parent_id).maximum(:position) || 0) + 1
  end

  def ancestors
    parent ? parent.ancestors + [parent] : []
  end
end