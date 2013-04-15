require 'bundler/setup'
require 'patches'
require 'sinatra'
require 'kag/config'
require 'kag/database'
require 'kag/models/model'
Dir.glob('lib/kag/models/*.rb').each {|f| load f.to_s }
require 'api/controllers/base'
KAG.ensure_database

set :environment, KAG::Config.instance[:branch].to_sym
set :root, File.dirname(__FILE__)+'/lib'

get "/*" do
  KAG::API::Controller::Base.route('get',params)
end

post "/*" do
  KAG::API::Controller::Base.route('post',params)
end

put "/*" do
  KAG::API::Controller::Base.route('put',params)
end

delete "/*" do
  KAG::API::Controller::Base.route('delete',params)
end

