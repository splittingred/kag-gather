require 'cinch'
require 'symboltable'
require 'json'
require 'kagerator'
require 'kag/config'
require 'socket'

module KAG
  class Server < SymbolTable
    def info
      Kagerator.server(self[:ip],self[:port])
    end

    def has_rcon?
      self[:rcon_password] and !self[:rcon_password].empty?
    end

    def socket
      unless self[:_socket]
        self[:_socket] = TCPSocket.new(self[:ip],self[:port])
      end
      self[:_socket]
    end

    def connect
      return false unless self.socket
      self.socket.puts self[:rcon_password]
      z = self.socket.gets
      puts z
      z.include?("now authenticated")
    end

    def disconnect
      if self[:_socket]
        self[:_socket].close
      end
    end

    def players
      self.socket.puts "/players"

      players = []
      while (line = self.socket.gets)
        puts line
        break if line[10..line.length].rstrip.empty?

        player = SymbolTable.new
        line = line[10..line.length].strip

        # get nick
        sp = line.index("[")
        next if sp == nil
        ep = line.index("]",sp)
        player[:nick] = line[(sp+1)..(ep-1)]
        line = line[ep..line.length].strip

        # get id
        sp = line.index("(")
        ep = line.index(")",sp)
        player[:id] = line[(sp+4)..(ep-1)]
        line = line[ep..line.length]

        # get ip
        sp = line.index("(")
        ep = line.index(")",sp)
        player[:ip] = line[(sp+4)..(ep-1)]
        line = line[ep..line.length]

        # get hwid
        sp = line.index("(")
        ep = line.index(")",sp)
        player[:hwid] = line[(sp+6)..(ep-1)]

        players << player
      end
      players
    end

    def kick(nick)
      self.socket.puts "/kick #{nick}"
    end

    def kick_all
      ps = self.players
      ps.each do |player|
        self.socket.puts "/kick #{player[:nick]}"
      end
    end

    def restart_map
      self.socket.puts "/restartmap"
    end

    def next_map
      self.socket.puts "/nextmap"
    end
  end
end