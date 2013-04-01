require 'symboltable'

module KAG
  module Server
    class Parser
      attr_accessor :server,:data,:live,:ready,:veto,:listener
      attr_accessor :units_depleted,:wins,:players_there
      attr_accessor :players

      def initialize(listener,data)
        self.server = listener.server
        self.listener = listener
        self.wins = []
        self.ready = []
        self.veto = []
        self.players = self.server.match.players.keys
        self.players_there = self.players.length
        self.data = data.merge({
          :units_depleted => false,
          :wins => [],
          :match_start => Time.now,
          :match_end => nil,
          :players => {},
          :started => false,
        })
        self.live = false
      end
      def parse(msg)
        return false if msg.to_s.empty?
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
          elsif msg.index(/^(?:Player) (.{0,7}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) (?:left the game \(players left [0-9]+\))$/)
            self.evt_player_left(msg)
          end
        else
          puts "[WARMUP] "+msg.to_s
          if msg.index("!ready")
            self.evt_ready(msg)
          elsif msg.index("!veto")
            self.evt_veto(msg)
          elsif msg.index("!hello")
            self.evt_hello(msg)
          end
        end
      end

      def end_match
        self.data[:end] = Time.now

        wins = data[:wins]
        if wins and wins.length > 0
          freq = wins.inject(Hash.new(0)) { |h,v| h[v] += 1; h }
          self.data[:winner] = wins.sort_by { |v| freq[v] }.last
        else
          self.data[:winner] = "Neither Team"
        end

        if self.server.match.teams
          self.server.match.teams.each do |team|
            team.players.each do |authname,user|
              u = KAG::User::User.new(user)
              if team.teammates[authname.to_sym]
                stat = team.teammates[authname.to_sym].to_s.downcase+"_plays"
                u.add_stat(stat.to_sym)
              end
              if team[:name] == winner
                u.add_stat(:wins)
              end
              if data.players and u.linked? and data.players[u.kag_user]
                u.merge!(data.players[u.kag_user])
              end
              u.save
            end
            self.listener.kick_all
          end
        end

        archive
        self.listener.stop_listening
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
            if self.players
              ready_threshold = _get_ready_threshold(self.players.length)
            else
              ready_threshold = _get_ready_threshold(KAG::Config.instance[:match_size])
            end
            if self.ready.length == ready_threshold
              start
            end
            say "Ready count now at #{self.ready.length.to_s} of #{ready_threshold.to_s} needed."
            :ready
          end
        end
      end

      def _get_ready_threshold(num_of_players)
        half = (num_of_players / 2)
        half + (half / 2).ceil
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
              self.listener.next_map
              self.ready = []
              self.veto = []
            end
            say "Veto count now at #{self.veto.length.to_s} of #{veto_threshold.to_s} needed."
            :veto
          end
        end
      end

      def evt_hello(msg)
        match = msg.match(/^(<)?(.{0,7}[ \.,\["\{\}><\|\/\(\)\\\+=])?([\w\._\-]{1,20})?(>) (?:!hello)$/)
        if match
          say "Hello #{match[3]}!"
        end
      end

      def start
        self.players_there = self.server.match.players.length if self.server and self.server.match and self.server.match.players
        self.listener.restart_map
        self.live = true
        self.units_depleted = false
        say "Match is now LIVE!"
      end

      # stats events

      def evt_units_depleted(msg)
        :units_depleted
      end
      def evt_map_restart(msg)
        #broadcast "Map on #{self.server[:key]} has been restarted!"
        self.ready = []
        self.veto = []
        :map_restart
      end
      def evt_match_started(msg)
        #broadcast "Match has started on #{self.server[:key]}"
        :match_start
      end
      def evt_match_ended(msg)
        self.data[:end] = Time.now
        self.ready = []
        self.veto = []
        :match_end
      end
      def evt_match_win(msg)
        self.live = false
        match = msg.match(/^(.+) (wins the game!)$/)
        if match
          self.data[:wins] << match[1]
          say("Match has now ended. #{match[1]} team wins!")
          if self.data[:wins].length >= 3
            end_match
          end
        end
        self.ready = []
        :match_win
      end
      def evt_player_joined(msg)

        :player_joined
      end
      def evt_player_join_renamed(msg)
        match = msg.match(/^Unnamed player is now known as (.{0,6}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20})$/)
        if match
          player = match[2]
          if self.players.include?(player.to_s.to_sym)
            self.players_there = self.players_there + 1
            say "Back up to #{self.players_there.to_s} people of required #{self.players.length} in the match!"
          end
        end
        :player_joined_renamed
      end
      def evt_player_renamed(msg)
        :player_renamed
      end
      def evt_player_left(msg)
        match = msg.match(/^(?:Player) (.{0,7}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) (?:left the game \(players left [0-9]+\))$/)
        if match
          player = match[2]
          if self.players.include?(player.to_s.to_sym)
            self.players_there = self.players_there - 1
            say "Down to #{self.players_there.to_s} people of required #{self.players.length} in the match!"
          end
        end
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
        self.listener.msg(msg) if self.listener and self.listener.respond_to?(:msg)
      end

      def _add_stat(stat,player,increment = 1)
        stat = stat.to_sym
        player = player.to_sym
        if self.data.players
          self.data.players[player] = {} unless self.data.players[player]
          self.data.players[player][stat] = 0 unless self.data.players[player][stat]
          self.data.players[player][stat] = self.data.players[player][stat] + increment.to_i
          self.data.players[player][stat]
        end
      end

      def _add_kill_type(type,player,increment = 1)
        type = type.to_sym
        player = player.to_sym
        if self.data.players
          self.data.players[player] = {} unless self.data.players[player]
          self.data.players[player][:kill_types] = {} unless self.data.players[player][:kill_types]
          self.data.players[player][:kill_types][type] = 0 unless self.data.players[player][:kill_types][type]
          self.data.players[player][:kill_types][type] = self.data.players[player][:kill_types][type] + increment.to_i
        end
      end

      def _add_death_type(type,player,increment = 1)
        type = type.to_sym
        player = player.to_sym
        if self.data.players
          self.data.players[player] = {} unless self.data.players[player]
          self.data.players[player][:death_types] = {} unless self.data.players[player][:death_types]
          self.data.players[player][:death_types][type] = 0 unless self.data.players[player][:death_types][type]
          self.data.players[player][:death_types][type] = self.data.players[player][:death_types][type] + increment.to_i
        end
      end

      def archive
        match = self.data
        match[:server] = self.listener.server.key
        ts = []
        if self.listener.server.match.teams
          self.listener.server.match.teams.each do |team|
            ts << {:players => team.teammates,:color => team[:color],:name => team[:name]}
          end
          match[:teams] = ts
        end
        match.delete(:players)
        match.delete(:bot) if match.key?(:bot)

        unless File.exists?("data/matches.json")
          File.open("data/matches.json","w") {|f| f.write("{}") }
        end

        data = Hash.new
        d = ::IO.read("data/matches.json")
        if d and !d.empty?
          data = Hash.new
          data.merge!(JSON.parse(d))
        end

        data[Time.now.to_s] = match
        File.open("data/matches.json","w") do |f|
          f.write(data.to_json)
        end
        true
      end
    end
  end
end