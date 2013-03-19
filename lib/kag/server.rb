require 'cinch'
require 'symboltable'
require File.dirname(__FILE__)+'/config'

module KAG
  class Server < SymbolTable
    def info

      #sinfo = json.loads(urllib.request.urlopen("https://api.kag2d.com/server/ip/{}/port/{}/status".format(addr[0], addr[1])).read().decode())
      #if len(sinfo["serverStatus"]["playerList"]) < gather.siz2:
      #    return True
      #else:
      #    return False
    end
  end
end