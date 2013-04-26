require 'symboltable'
require 'celluloid'
require 'kag/server/parser'
require 'logger'

module KAG
  module Server
    class Listener
      include ::Celluloid

      attr_accessor :server,:socket,:connected,:data,:parser,:data,:log

      trap_exit :actor_died

      def actor_died(actor, reason)
        self.log.error "Oh no! #{actor.inspect} has died because of a #{reason.class}"
      end

      def initialize(server)
        self.server = server
        self.data = server.match_data
        self.socket = nil
        self.log = ::Logger.new("log/matches/#{self.server.match_in_progress.id}.log")
        self.log.level = ::Logger::INFO
      end

      def start_listening
        return false unless self.connect
        self.log.info 'Setting up parser'
        self.parser = KAG::Server::Parser.new(self,self.data)
        self.restart_map
        @twiddle = true

        while (buffer = get) and @twiddle
          lines = buffer.split("\n")
          lines.each do |line|
            begin
              self.parser.parse(line)
            rescue Exception => e
              self.log.error e.message
              self.log.error e.backtrace.join("\n")
            end
          end
          #self.log.info "twiddling..."
          sleep 0.2
        end
        self.log.info 'ending...'
      end

      def stop_listening
        @twiddle = false
        self.log.info 'In Listener.stop_listening'

        self.data[:end] = Time.now
        self.parser.archive
        self.data = self.parser.data

        self.socket.close
        KAG::Listener.delete_registered(self.server.name.to_sym)
        begin
          ActiveRecord::Base.connection.close
        rescue Exception => e
          self.log.error e.message
          self.log.error e.backtrace.join("\n")
        end
        self.terminate
        self.log.info 'Listener self.terminate run'
        self.data
      end

      def connect
        return true if self.connected?
        self.log.info "[Server] Attempting to connect via socket to #{self.server.ip}:#{self.server.port}"
        self.socket = TCPSocket.new(self.server.ip,self.server.port.to_i)
        self.socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
        unless self.socket
          self.log.error '[Server] Could not establish TCP socket to connect'
          return false
        end
        success = false
        begin
          put self.server.rcon_password
          z = get
          self.log.info "[RCON] "+z.to_s
          z.include?('now authenticated')
          self.connected = true
          success = true
        rescue Exception => e
          self.log.error e.message
          self.log.error e.backtrace.join("\n")
        end
        self.log.info "[Server] Connected! #{success.to_s}"
        success
      end

      def disconnect
        if self.socket
          self.log.info '[RCON] Closing socket...'
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
        _command '/players'

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
        self.log.info "Swapping #{nick}'s team"
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
          self.log.info "No Players found on Server #{self[:ip]}!"
        end
        _cycle
      end

      def restart_map
        return false unless self.connect
        _command '/restartmap'
        _cycle
      end

      def msg(msg)
        return false unless self.connect
        _command "/msg #{msg.to_s}"
        _cycle
      end

      def next_map
        return false unless self.connect
        _command '/nextmap'
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
        msg = ''
        begin
          ready = IO.select([self.socket],nil,nil,2)
          if ready
            msg = self.socket.gets
          else
            msg = ''
          end
        rescue Exception => e
          self.log.error e.message
          self.log.error e.backtrace.join("\n")
        end
        msg
      end

      def put(msg)
        self.socket.puts(msg+"\r\n")
      end

      def _command(cmd)
        return false unless self.connected?
        self.log.info "[RCON] #{cmd.to_s}"
        put cmd
      end
    end
  end
end