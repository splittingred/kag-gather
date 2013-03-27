require 'symboltable'

module KAG
  module Server
    class Parser
      attr_accessor :server,:data,:live,:ready,:veto
      attr_accessor :match_start,:match_end,:rcon_block,:units_depleted,:wins

      def initialize(server)
        self.server = server
        self.wins = []
        self.ready = []
        self.veto = []
        self.data = SymbolTable.new({
          :units_depleted => false,
          :wins => [],
          :match_start => nil,
          :match_end => nil,
          :players => {},
          :started => false,
        })
        self.live = false
      end
      def parse(msg)
        msg = msg[11..msg.length]
        if msg.index("*Restarting Map*")
          self.evt_map_restart(msg)
        elsif msg.index("*Match Started*")
          self.evt_match_started(msg)
        elsif msg.index("*Match Ended*")
          self.evt_match_ended(msg)
        elsif msg.index(/^Unnamed player is now known as (.{0,6}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20})$/)
          self.evt_player_join_renamed(msg)
        elsif msg.index(/^(.{0,6}[ \.,\["\{\}><\|\/\(\)\\\+=])?([\S]{1,20}) (?:is now known as) (.{0,6}[ \.,\["\{\}><\|\/\(\)\\\+=])?([\S]{1,20})$/)
          self.evt_player_renamed(msg)

        elsif self.live
          puts "[LIVE] "+msg.to_s
          if msg.index(/^(.+) (wins the game!)$/)
            self.evt_match_win(msg)
          elsif msg.index(/^(.+) (slew|gibbed|shot|hammered|pushed|assisted|squashed|fell|took|died) (.+)$/)
            self.evt_kill(msg)
          elsif msg.index("Can't spawn units depleted")
            self.evt_units_depleted(msg)
          end
        else
          puts "[WARMUP] "+msg.to_s
          if msg.index("!ready")
            self.evt_ready(msg)
          elsif msg.index("!veto")
            self.evt_veto(msg)
          end
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



      def evt_ready(msg)
        match = msg.match(/^(<)?(.{0,7}[ \.,\["\{\}><\|\/\(\)\\\+=])?([\w\._\-]{1,20})?(>) (?:!ready)$/)
        if match
          unless self.ready.include?(match[3])
            self.ready << match[3]
            if self.server and self.server.match and self.server.match.players
              match_size = self.server.match.players.length
            else
              match_size = KAG::Config.instance[:match_size]
            end
            if self.ready.length == match_size
              start
            end
            say "Ready count now at #{self.ready.length.to_s} of #{match_size.to_s} needed."
            :ready
          end
        end
      end

      def evt_veto(msg)
        match = msg.match(/^(<)?(.{0,7}[ \.,\["\{\}><\|\/\(\)\\\+=])?([\w\._\-]{1,20})?(>) (?:!veto)$/)
        if match
          unless self.veto.include?(match[3])
            if self.server and self.server.match and self.server.match.players
              veto_threshold = (self.server.match.players.length / 2).to_i
            else
              veto_threshold = (KAG::Config.instance[:veto_threshold] or 5)
            end
            self.veto << match[3]
            if self.veto.length == veto_threshold
              self.server.next_map
              self.ready = []
              self.veto = []
            end
            say "Veto count now at #{self.veto.length.to_s} of #{veto_threshold.to_s} needed."
            :veto
          end
        end
      end

      def start
        self.server.restart_map
        self.live = true
        say "Match is now LIVE!"
      end


      # stats events

      def evt_units_depleted(msg)
        :units_depleted
      end
      def evt_map_restart(msg)
        #broadcast "Map on #{self.server[:key]} has been restarted!"
        :map_restart
      end
      def evt_match_started(msg)
        broadcast "Match has started on #{self.server[:key]}"
        self.match_start = Time.now
        self.rcon_block = false
        self.units_depleted = false
        :match_start
      end
      def evt_match_ended(msg)
        self.match_end = Time.now
        #self.match_ended = true
        self.rcon_block = true
        :match_end
      end
      def evt_match_win(msg)
        self.live = false
        match = msg.match(/^(.+) (wins the game!)$/)
        if match
          self.data[:wins] << match[1]
          say("Match has now ended. #{match[1]} team wins!")
          if self.data[:wins].length >= 3
            self.server.match.cease
          end
        end
        self.ready = []
        :match_win
      end
      def evt_player_joined(msg)

        :player_joined
      end
      def evt_player_join_renamed(msg)

        :player_joined_renamed
      end
      def evt_player_renamed(msg)
        :player_renamed
      end
      def evt_player_left(msg)
        :player_left
      end
      def evt_player_chat(msg)
        :player_chat
      end

      def evt_kill(msg)
        # slew
        if (match = msg.match(/^(.{0,6}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) slew (.{0,6}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) with (?:his|her) sword$/))
          _add_stat(:kill,match[2])
          _add_kill_type(:gibbed,match[2])
          _add_stat(:death,match[4])
          _add_death_type(:gibbed,match[4])
          :slew

        # gibbed
        elsif (match = msg.match(/^(.{0,6}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) gibbed (.{0,6}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20})? into pieces$/))
          _add_stat(:kill,match[2])
          _add_kill_type(:gibbed,match[2])
          _add_stat(:death,match[4])
          _add_death_type(:gibbed,match[4])
          :gibbed

        # shot
        elsif (match = msg.match(/^(.{0,6}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) shot (.{0,6}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) with (?:his|her) arrow$/))
          _add_stat(:kill,match[2])
          _add_kill_type(:shot,match[2])
          _add_stat(:death,match[4])
          _add_death_type(:shot,match[4])
          :shot

        # hammered
        elsif (match = msg.match(/^(.{0,6}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) hammered (.{0,6}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) to death$/))
          _add_stat(:kill,match[2])
          _add_kill_type(:hammered,match[2])
          _add_stat(:death,match[4])
          _add_death_type(:hammered,match[4])
          :hammered

        # pushed
        elsif (match = msg.match(/^(.{0,6}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) pushed (.{0,6}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) (?:on a spike trap|to his death)$/))
          _add_stat(:kill,match[2])
          _add_kill_type(:pushed,match[2])
          _add_stat(:death,match[4])
          _add_death_type(:pushed,match[4])
          :pushed

        # assisted
        elsif (match = msg.match(/^(.{0,6}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) assisted in(?: squashing)? (.{0,6}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20})(?: dying)? under (?:a collapse|falling rocks)$/))
          _add_stat(:kill,match[2])
          _add_kill_type(:assisted,match[2])
          if match[4].strip == "dying"
            _add_stat(:death,match[3].strip)
            _add_death_type(:assisted,match[3])
          else
            _add_stat(:death,match[4])
            _add_death_type(:assisted,match[4])
          end
          :assisted

        # squashed
        elsif (match = msg.match(/^(.{0,6}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) was squashed under a collapse$/))
          _add_stat(:death,match[2])
          _add_death_type(:squashed,match[2])
          :squashed

        # fell
        elsif (match = msg.match(/^(.{0,6}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) fell (?:(?:to (?:his|her) death)|(?:on a spike trap))$/))
          _add_stat(:death,match[2])
          _add_death_type(:fell,match[2])
          :fell

        # cyanide
        elsif (match = msg.match(/^(.{0,6}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) took some cyanide$/))
          _add_stat(:death,match[2])
          _add_death_type(:cyanide,match[2])
          :cyanide

        # died
        elsif (match = msg.match(/^(.{0,6}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) died under falling rocks$/))
          _add_stat(:death,match[2])
          _add_death_type(:died,match[2])
          :died
        else
          :unknown
        end
      end

      private

      def say(msg)
        self.server.msg(msg) if self.server and self.server.respond_to?(:msg)
      end

      def _add_stat(stat,player,increment = 1)
        stat = stat.to_sym
        player = player.to_sym
        self.data.players[player] = {} unless self.data.players[player]
        self.data.players[player][stat] = 0 unless self.data.players[player][stat]
        self.data.players[player][stat] = self.data.players[player][stat] + increment.to_i
        self.data.players[player][stat]
      end

      def _add_kill_type(type,player,increment = 1)
        type = type.to_sym
        player = player.to_sym
        self.data.players[player] = {} unless self.data.players[player]
        self.data.players[player][:kill_types] = {} unless self.data.players[player][:kill_types]
        self.data.players[player][:kill_types][type] = 0 unless self.data.players[player][:kill_types][type]
        self.data.players[player][:kill_types][type] = self.data.players[player][:kill_types][type] + increment.to_i
      end

      def _add_death_type(type,player,increment = 1)
        type = type.to_sym
        player = player.to_sym
        self.data.players[player] = {} unless self.data.players[player]
        self.data.players[player][:death_types] = {} unless self.data.players[player][:death_types]
        self.data.players[player][:death_types][type] = 0 unless self.data.players[player][:death_types][type]
        self.data.players[player][:death_types][type] = self.data.players[player][:death_types][type] + increment.to_i
      end
    end
  end
end