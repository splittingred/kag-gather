require 'bundler/setup'
require 'kag/config'
require 'kag/database'
require 'kag/models/model'
Dir.glob('lib/kag/models/*.rb').each {|f| load f.to_s }
KAG.ensure_database