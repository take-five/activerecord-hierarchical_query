# coding: utf-8
require 'pathname'
require 'logger'

ENV['TZ'] = 'UTC'
ENV['DB'] ||= 'pg'

SPEC_ROOT = Pathname.new(File.dirname(__FILE__))

require 'bundler'
Bundler.setup(:default, ENV['TRAVIS'] ? :travis : :local, ENV['DB'].to_sym)

require 'rspec'
require 'database_cleaner'
require 'active_record'

ActiveRecord::Base.configurations = YAML.load(SPEC_ROOT.join('database.yml').read)
ActiveRecord::Base.establish_connection(ENV['DB'].to_sym)
ActiveRecord::Base.logger = Logger.new(ENV['DEBUG'] ? $stderr : '/dev/null')
ActiveRecord::Base.logger.formatter = proc do |severity, datetime, progname, msg|
  "#{datetime.strftime('%H:%M:%S.%L')}: #{msg}\n"
end

load SPEC_ROOT.join('schema.rb')
require SPEC_ROOT.join('support', 'models').to_s

DatabaseCleaner.strategy = :transaction

# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = 'random'

  config.around(:each) do |example|
    DatabaseCleaner.start
    example.run
    DatabaseCleaner.clean
  end
end

if ENV['TRAVIS']
  require 'coveralls'
  Coveralls.wear!
else
  require 'simplecov'
  SimpleCov.start
end

require 'active_record/hierarchical_query'
