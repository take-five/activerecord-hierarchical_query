# coding: utf-8
require 'pathname'
require 'logger'

begin
  require 'pry'
rescue LoadError
end

ENV['TZ'] = 'UTC'

SPEC_ROOT = Pathname.new(File.dirname(__FILE__)) unless defined? SPEC_ROOT

require 'bundler'
Bundler.setup(:default, ENV['TRAVIS'] ? :travis : :local)

require 'rspec'
require 'database_cleaner'
require 'active_record'

ActiveRecord::Base.configurations = YAML.load(SPEC_ROOT.join('database.yml').read)
ActiveRecord::Base.establish_connection(:pg)

ActiveRecord::Base.logger = Logger.new(ENV['DEBUG'] ? $stderr : '/dev/null')
ActiveRecord::Base.logger.formatter = proc do |severity, datetime, progname, msg|
  "#{datetime.strftime('%H:%M:%S.%L')}: #{msg}\n"
end

begin
  load SPEC_ROOT.join('schema.rb')
rescue ActiveRecord::NoDatabaseError
  bold  = "\033[1m"
  red   = "\033[31m"
  reset = "\033[0m"

  puts ""
  puts bold + red + "Database missing." + reset
  puts "If you have #{bold}sudo#{reset}, run the below " +
       "(ignore any role creation errors)."
  puts ""
  puts bold + "rake db:create" + reset
  puts ""
  exit
end

require SPEC_ROOT.join('support', 'models').to_s

DatabaseCleaner.strategy = :transaction

RSpec.configure do |config|

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
