require 'symboltable'
require 'celluloid'
require 'kag/server/parser'

module KAG
  module Server
    class Listener
      include ::Celluloid

      attr_accessor :server,:_socket,:connected,:data,:parser,:data

      def initialize(server,data)
        self.server = server
        self.data = data
      end

      def start
        self.parser = KAG::Server::Parser.new(self.server,self,self.data)
        self.restart_map
        @twiddle = true
        while @twiddle
          z = get.to_s
          self.parser.parse(z)
          puts "twiddle..."
          sleep 0.5
        end
        puts "ending..."
      end

      def stop
        # NOT WORKING
        puts "Stopping listener"
        self.data = self.parser.data
        @twiddle = false

        #self.archive
        KAG::Stats::Main.add_stat(:matches_completed)
        #if self.teams
          #self.teams.each do |team|
          #  team.kick_all
          #end
        #end
        self.disconnect
        self.data
      end

      def socket
        unless self._socket
          begin
            self._socket = TCPSocket.new(self.server.ip,self.server.port)
          rescue Exception => e
            puts e.message
            puts e.backtrace.join("\n")
          end
        end
        self._socket
      end

      def connect
        return true if self.connected?
        puts "[Server] Attempting to get socket"
        unless self.socket
          puts "[Server] Could not establish TCP socket to connect"
          return false
        end
        success = false
        begin
          put self.server.rcon_password
          z = self.socket.gets
          puts "[RCON] "+z.to_s
          z.include?("now authenticated")
          self.connected = true
          success = true
        rescue Exception => e
          puts e.message
          puts e.backtrace.join("\n")
        end
        puts "[Server] Connected!"
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
        put "/kick #{nick}"
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
        line.strip
      end

      def _cycle
        self.get
      end

      def get
        msg = ""
        begin
          msg = self.socket.gets
        rescue Exception => e
          puts e.message
          puts e.backtrace.join("\n")
        end
        msg
      end

      def put(msg)
        self.socket.puts(msg)
      end

      def _command(cmd)
        return false unless self.connected?
        puts "[RCON] #{cmd.to_s}"
        put cmd
      end
    end
  end
end