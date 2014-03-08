require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec, :db) do |t, args|
  ENV['DB'] = args[:db] || 'pg'
end