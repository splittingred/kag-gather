# this rackup file is used to run the application
# when run via the Thin rack interace 

require 'rubygems'
require 'sinatra'

set :run, false

# then load and run the application
load 'lib/server.rb'
run Sinatra.application