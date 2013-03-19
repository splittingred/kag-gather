require 'cinch'
require 'symboltable'
require 'json'
require 'kagerator'
require File.dirname(__FILE__)+'/config'

module KAG
  class Server < SymbolTable
    def info
      Kagerator.server(self[:ip],self[:port])
    end
  end
end