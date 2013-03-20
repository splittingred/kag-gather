require 'cinch'
require 'symboltable'
require 'json'
require 'kagerator'
require 'kag/config'

module KAG
  class Server < SymbolTable
    def info
      Kagerator.server(self[:ip],self[:port])
    end
  end
end