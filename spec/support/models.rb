class Category < ActiveRecord::Base
  @@generator = Enumerator.new do |y|
    num ||= 1
    y << "category #{n}"
    num += 1
  end

  belongs_to :parent, :class_name => 'Category'
  has_many :children, :class_name => 'Category'

  before_save :generate_name, :unless => :name?

  def generate_name
    self.name = @@generator.next
  end
end