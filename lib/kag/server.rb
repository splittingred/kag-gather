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

    def in_use?
      self.key?(:match)
    end

    def has_rcon?
      self[:rcon_password] and !self[:rcon_password].empty?
    end

    def socket
      unless self[:_socket]
        self[:_socket] = TCPSocket.new(self[:ip],self[:port])
      end
      puts self[:_]
      self[:_socket]
    end

    def text_join
      "Join \x0305#{self[:key]} - #{self[:ip]}:#{self[:port]} \x0306password #{self[:password]}\x0301 | Visit kag://#{self[:ip]}/#{self[:password]}"
    end

    def connect
      return true if self.connected?
      puts "[RCON] Attempting to get socket"
      unless self.socket
        puts "[RCON] Could not establish TCP socket to connect"
        return false
      end
      success = false
      begin
        self.socket.puts self[:rcon_password]
        z = self.socket.gets
        puts "[RCON] "+z.to_s
        z.include?("now authenticated")
        self[:_connected] = true
        success = true
      rescue Exception => e
        puts e.message
        puts e.backtrace.join("\n")
      end
      success
    end

    def disconnect
      if self[:_socket]
        puts "[RCON] Closing socket..."
        #self.socket.puts "/quit"
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
      line.empty?
    end

    def _parse_line(line)
      line.gsub!(/\r/,"")
      line.gsub!(/\n/,"")
      line = line.strip
      ep = line.index(']')
      if ep
        line = line[(ep+1)..line.length].strip
      else
        line = line[10..line.length].strip
      end
      line.gsub!(/\r/,"")
      line.gsub!(/\n/,"")
      line
    end

    def _cycle
      while (line = self.socket.gets)
        line = _parse_line(line)
        puts "[RCON] "+line
        break if (_is_newline?(line) or line.empty?)
      end
    end

    ##
    # broken
    #
    def players
      return false unless self.connect
      _command "/rcon /players"

      players = []
      while (line = self.socket.gets)
        puts "[RCONPRIOR] '"+line+"'"
        line = _parse_line(line)
        puts "[RCON] '"+line+"'"
        break if (line.empty? or line == '' or line == "\n")

        player = SymbolTable.new

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