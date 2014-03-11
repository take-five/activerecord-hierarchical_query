# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'active_record/hierarchical_query/version'

Gem::Specification.new do |spec|
  spec.name          = 'activerecord-hierarchical_query'
  spec.version       = ActiveRecord::HierarchicalQuery::VERSION
  spec.authors       = ['Alexei Mikhailov']
  spec.email         = %w(amikhailov83@gmail.com)
  spec.summary       = %q{Recursively traverse trees using a single SQL query}
  spec.homepage      = 'https://github.com/take-five/activerecord-hierarchical_query'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z {lib,bin,spec}`.split("\x0") + %w(README.md LICENSE.txt)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = %w(lib)

  spec.add_dependency 'activerecord', '>= 3.1.0'

  spec.add_development_dependency 'bundler', '~> 1.5'
  spec.add_development_dependency 'rake', '~> 10.1.1'
  spec.add_development_dependency 'rspec', '~> 2.14.1'
  spec.add_development_dependency 'pg', '~> 0.17.1'
  spec.add_development_dependency 'database_cleaner', '~> 1.2.0'
  spec.add_development_dependency 'simplecov', '~> 0.8.2'
end
