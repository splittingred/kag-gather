require 'symboltable'

module KAG
  module Server
    class Parser
      attr_accessor :server,:data
      attr_accessor :match_start,:match_end,:rcon_block,:units_depleted,:wins

      def initialize(server)
        self.server = server
        self.wins = []
        self.data = SymbolTable.new({
          :units_depleted => false,
          :wins => [],
          :match_start => nil,
          :match_end => nil,
          :players => {},
        })
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
        elsif msg.index(/^(.+) (slew|gibbed|shot|hammered|pushed|assisted|squashed|fell|took|died) (.+)$/)
          self.evt_kill(msg)
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
          self.data[:wins] << match[1]
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

      def evt_kill(msg)
        # slew
        if (match = msg.match(/^(.{0,5}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) slew (.{0,5}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) with (?:his|her) sword$/))
          self._add_stat(:kill,match[2])
          self._add_stat(:death,match[4])
          :slew

        # gibbed
        elsif (match = msg.match(/^(.{0,5}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) gibbed (.{0,5}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20})? into pieces$/))
          self._add_stat(:kill,match[2])
          self._add_stat(:death,match[4])
          :gibbed

        # shot
        elsif (match = msg.match(/^(.{0,5}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) shot (.{0,5}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) with (?:his|her) arrow$/))
          self._add_stat(:kill,match[2])
          self._add_stat(:death,match[4])
          :shot

        # hammered
        elsif (match = msg.match(/^(.{0,5}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) hammered (.{0,5}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) to death$/))
          self._add_stat(:kill,match[2])
          self._add_stat(:death,match[4])
          :hammered

        # pushed
        elsif (match = msg.match(/^(.{0,5}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) pushed (.{0,5}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) (?:on a spike trap|to his death)$/))
          self._add_stat(:kill,match[2])
          self._add_stat(:death,match[4])
          :pushed

        # assisted
        elsif (match = msg.match(/^(.{0,5}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) assisted in(?: squashing)? (.{0,5}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20})(?: dying)? under (?:a collapse|falling rocks)$/))
          self._add_stat(:kill,match[2])
          if match[4].strip == "dying"
            self._add_stat(:death,match[3].strip)
          else
            self._add_stat(:death,match[4])
          end
          :assisted

        # squashed
        elsif (match = msg.match(/^(.{0,5}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) was squashed under a collapse$/))
          self._add_stat(:death,match[2])
          :squashed

        # fell
        elsif (match = msg.match(/^(.{0,5}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) fell (?:(?:to (?:his|her) death)|(?:on a spike trap))$/))
          self._add_stat(:death,match[2])
          :fell

        # cyanide
        elsif (match = msg.match(/^(.{0,5}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) took some cyanide$/))
          self._add_stat(:death,match[2])
          :cyanide

        # died
        elsif (match = msg.match(/^(.{0,5}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) died under falling rocks$/))
          self._add_stat(:death,match[2])
          :died
        else
          :unknown
        end
      end

      def _add_stat(stat,player,increment = 1)
        stat = stat.to_sym
        player = player.to_sym
        self.data.players[player] = {} unless self.data.players[player]
        self.data.players[player][stat] = 0 unless self.data.players[player][stat]
        self.data.players[player][stat] = self.data.players[player][stat] + increment.to_i
        self.data.players[player][stat]
      end
    end
  end
end