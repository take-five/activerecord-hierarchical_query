require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

task default: :spec

namespace :db do
  task :create do
    sql  = "CREATE ROLE $PG_USER WITH SUPERUSER LOGIN;\n"
    sql += "         CREATE DATABASE hierarchical_query_test OWNER = $PG_USER;"

    command  = "sudo PG_USER=$USER -H -u postgres bash -c \\\n"
    command += "  'echo \"#{sql}\" | psql'"

    system command
  end
end
