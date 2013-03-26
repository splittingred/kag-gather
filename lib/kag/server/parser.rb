module KAG
  module Server
    class Parser
      attr_accessor :server,:match_start,:match_end,:rcon_block,:units_depleted,:wins

      def initialize(server)
        self.server = server
        self.wins = []
      end
      def parse(msg)
        puts msg.to_s

        if msg.index("*Restarting Map*")
          self.evt_map_restart(msg)
        elsif msg.index("*Match Started*")
          self.evt_match_started(msg)
        elsif msg.index("*Match Ended*")
          self.evt_match_ended(msg)
        elsif msg.index(/^(.+) (wins the game!)$/)
          self.evt_match_win(msg)
        end
      end

      def broadcast(msg)
        if KAG::Config.instance[:channels] and self.server and self.server.bot
          KAG::Config.instance[:channels].each do |c|
            channel = self.server.bot.channel_list.find_ensured(c)
            if channel
              channel.send(msg)
            end
          end
        end
      end



      def evt_units_depleted(msg)

      end
      def evt_map_restart(msg)
        #broadcast "Map on #{self.server[:key]} has been restarted!"
      end
      def evt_match_started(msg)
        broadcast "Match has started on #{self.server[:key]}"
        self.match_start = Time.now
        self.rcon_block = false
        self.units_depleted = false
      end
      def evt_match_ended(msg)
        self.match_end = Time.now
        #self.match_ended = true
        self.rcon_block = true
      end
      def evt_match_win(msg)
        match = msg.match(/^(.+) (wins the game!)$/)
        if match
          self.wins << match[1]
        end
      end
      def evt_player_joined(msg)

      end
      def evt_player_nick(msg)

      end
      def evt_player_left(msg)

      end
      def evt_player_chat(msg)

      end
    end
  end
end