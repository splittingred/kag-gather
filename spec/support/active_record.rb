require 'active_record'
require 'kag/database'

KAG::Config.instance[:branch] = "test"

KAG.ensure_database