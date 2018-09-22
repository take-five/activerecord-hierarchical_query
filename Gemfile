source 'https://rubygems.org'

# Specify your gem's dependencies in activerecord-hierarchical_query.gemspec
gemspec

gem 'pg', '>= 0.21', '< 1.2'
gem 'activerecord', '>= 5.0', '< 5.3'

group :local do
  gem 'yard'
  gem 'redcarpet'
  gem 'github-markup'
  gem 'appraisal', '>= 1.0.0'
end

group :development do
  gem 'pry'
end

group :travis do
  gem 'coveralls', '~> 0.8.21'
end
