$:.push File.expand_path('../lib', __FILE__)
require 'rubygems'
require 'bundler/setup'
require 'database_cleaner'
require 'seed-fu'

RSpec.configure do |config|
  config.filter_run :focus => true
  config.run_all_when_everything_filtered = true
  config.around do |example|
    ActiveRecord::Base.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
    SeedFu.seed
  end

  config.before(:each) do
    #DatabaseCleaner.start
  end

  config.after(:each) do
    #DatabaseCleaner.clean
  end

  config.after(:suite) do
    DatabaseCleaner.clean
  end
end