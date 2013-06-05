# this rackup file is used to run the application
# when run via the Thin rack interace 

require 'rubygems'
require 'sinatra'

# we need to manually specify where our views live
Sinatra::Application.default_options.merge!(
  :run => false,
  :env => :production 
) 

# then load and run the application
load 'lib/server.rb'
run Sinatra.application