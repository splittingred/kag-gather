require 'json'
require 'symboltable'
require 'spec_helper'
require 'support/active_record'
require 'kag/common'
Dir.glob('lib/kag/models/*.rb').each {|f| load f.to_s }

require 'support/match_setup'
require 'kag/bot'
