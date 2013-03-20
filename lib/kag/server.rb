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
      return true if self.connected?
      unless self.socket
        puts "Could not establish TCP socket to connect"
        return false
      end
      self.socket.puts self[:rcon_password]
      z = self.socket.gets
      z.include?("now authenticated")
      self[:_connected] = true
      true
    end

    def disconnect
      if self[:_socket]
        puts "[RCON] Closing socket..."
        self.socket.puts "/quit"
        self[:_socket].close
        self[:_connected] = false
        self.delete(:_socket)
      end
      true
    end

    def connected?
      self[:_connected]
    end

    def _is_newline?(line)
      line[10..line.length].rstrip.empty?
    end

    def _cycle
      while (line = self.socket.gets)
        puts line
        break if _is_newline?(line)
      end
    end

    def players
      return false unless self.connect
      _command "/players"

      players = []
      while (line = self.socket.gets)
        puts line
        break if _is_newline?(line)

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
      _cycle
      players
    end

    def kick(nick)
      return false unless self.connect
      self.socket.puts "/kick #{nick}"
      _cycle
    end

    def kick_all
      return false unless self.connect
      ps = self.players
      if ps
        ps.each do |player|
          _command "/kick #{player[:nick]}"
        end
      else
        puts "No Players found on Server #{self[:ip]}!"
      end
      _cycle
    end

    def restart_map
      return false unless self.connect
      _command "/restartmap"
      _cycle
    end

    def next_map
      return false unless self.connect
      _command "/nextmap"
      _cycle
    end

    protected

    def _command(cmd)
      return false unless self.connected?
      puts "[RCON] #{cmd.to_s}"
      self.socket.puts cmd
    end
  end
end