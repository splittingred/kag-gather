require 'symboltable'
require 'celluloid'
require 'kag/server/parser'

module KAG
  module Server
    class Listener
      include ::Celluloid

      attr_accessor :server,:socket,:connected,:data,:parser,:data

      trap_exit :actor_died

      def actor_died(actor, reason)
        p "Oh no! #{actor.inspect} has died because of a #{reason.class}"
      end

      def initialize(server)
        self.server = server
        self.data = server.match_data
        self.socket = nil
      end

      def start_listening
        return false unless self.connect
        self.parser = KAG::Server::Parser.new(self,self.data)
        self.restart_map
        @twiddle = true

        i = 0
        while (z = get) and @twiddle
          begin
            self.parser.parse(z)
          rescue Exception => e
            puts e.message
            puts e.backtrace.join("\n")
          end
          sleep 0.5
          i = i+1
        end
        puts "ending..."
      end

      def stop_listening
        @twiddle = false
        puts "Stopping listener"

        self.data[:end] = Time.now
        self.data = self.parser.data

        self.socket.close
        KAG::Listener.delete_registered(self.server.name.to_sym)
        self.terminate
        self.data
      end

      def connect
        return true if self.connected?
        puts "[Server] Attempting to connect via socket to #{self.server.host}:#{self.server.port}"
        self.socket = TCPSocket.new(self.server.host,self.server.port)
        self.socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
        unless self.socket
          puts "[Server] Could not establish TCP socket to connect"
          return false
        end
        success = false
        begin
          put self.server.rcon_password
          z = get
          puts "[RCON] "+z.to_s
          z.include?("now authenticated")
          self.connected = true
          success = true
        rescue Exception => e
          puts e.message
          puts e.backtrace.join("\n")
        end
        puts "[Server] Connected! #{success.to_s}"
        success
      end

      def disconnect
        if self.socket
          puts "[RCON] Closing socket..."
          #put "/quit"
          self.socket.close
          self.connected = false
          self._socket = nil
          true
        else
          false
        end
      end

      def connected?
        self.connected
      end

      ##
      # broken
      #
      def players
        return false unless self.connect
        _command "/players"

        players = {}
        while (line = get)
          next if line.to_s.length < 10
          line = line[10..line.length].strip
          break if (line.empty? or line == '' or line == "\n")

          match = line.strip.match(/^\[(.{0,6}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20})\] \(id ([0-9]+)\) \(ip (.+)\) \(hwid (.+)\)$/)
          if match
            player = SymbolTable.new
            player[:clan] = match[1].strip
            player[:nick] = match[2].strip
            player[:id] = match[3]
            player[:ip] = match[4]
            player[:hwid] = match[5]
            players[player[:nick].to_sym] = player
          end
        end
        players
      end

      def switch_team(nick)
        puts "Swapping #{nick}'s team"
        players = self.players
        if players.key?(nick.to_sym)
          id = players[nick.to_sym][:id]
          put "/swapid #{id}"
          _cycle
        end
      end

      def kick(nick)
        return false unless self.connect
        put "/kick #{nick}"
        _cycle
      end

      def kick_all
        return false unless self.connect
        ps = self.players
        if ps
          ps.each do |nick,player|
            _command "/kick #{nick.to_s}"
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

      def msg(msg)
        return false unless self.connect
        _command "/msg #{msg.to_s}"
        _cycle
      end

      def next_map
        return false unless self.connect
        _command "/nextmap"
        _cycle
      end

      protected

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
        line.strip.chop
      end

      def _cycle
        self.get
      end

      def get
        msg = ""
        begin
          ready = IO.select([self.socket],nil,nil,2)
          if ready
            msg = self.socket.gets
          else
            msg = ''
          end
        rescue Exception => e
          puts e.message
          puts e.backtrace.join("\n")
        end
        msg
      end

      def put(msg)
        self.socket.puts(msg+"\r\n")
      end

      def _command(cmd)
        return false unless self.connected?
        puts "[RCON] #{cmd.to_s}"
        put cmd
      end
    end
  end
end