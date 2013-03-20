require 'rubygems'
require 'bundler/setup'
require 'json'
require 'symboltable'

RSpec.configure do |config|
  config.filter_run :focus => true
  config.run_all_when_everything_filtered = true
end