require 'symboltable'
require 'kag/stats/main'
require 'kag/user/user'

module KAG
  module Server
    class Parser
      attr_accessor :server,:data,:live,:ready,:veto,:listener,:restart_queue
      attr_accessor :units_depleted,:players_there
      attr_accessor :players,:teams

      def initialize(listener,data)
        self.server = listener.server
        self.listener = listener
        self.ready = []
        self.veto = []
        self.restart_queue = []
        self.teams = self.server.match.teams
        self.players = self.server.match.players.keys
        self.players_there = 0
        self.data = data.merge({
          :units_depleted => false,
          :wins => {},
          :match_start => Time.now,
          :match_end => nil,
          :players => {},
          :started => false,
        })
        self.live = false
      end
      def parse(msg)
        return false if msg.to_s.empty? or msg.to_s.length < 11
        msg = msg[11..msg.length]
        if msg.index("*Restarting Map*")
          self.evt_map_restart(msg)
        elsif msg.index(/^(.{0,6}[ \.,\["\{\}><\|\/\(\)\\\+=])?([\S]{1,20}) (?:is now known as) (.{0,6}[ \.,\["\{\}><\|\/\(\)\\\+=])?([\S]{1,20})$/)
          self.evt_player_renamed(msg)
        elsif msg.index(/^Unnamed player is now known as (.{0,6}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20})$/)
          self.evt_player_join_renamed(msg)
        elsif msg.index(/^(?:Player) (.{0,7}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) (?:left the game \(players left [0-9]+\))$/)
          self.evt_player_left(msg)

        elsif self.live
          puts "[LIVE] "+msg.to_s
          if msg.index(/^(.+) (wins the game!)$/)
            self.evt_round_win(msg)
          elsif msg.index(/^(.+) (slew|gibbed|shot|hammered|pushed|assisted|squashed|fell|took|died) (.+)$/)
            self.evt_kill(msg)
          elsif msg.index("Can't spawn units depleted")
            self.evt_units_depleted(msg)
          elsif msg.index("*Match Started*")
            self.evt_round_started(msg)
          elsif msg.index("*Match Ended*")
            self.evt_round_ended(msg)
          elsif msg.index("!restart")
            self.evt_veto(msg)
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

      def _team_has_won
        self.data[:wins].each do |team,wins|
          if wins >= 2
            return team
          end
        end
        false
      end

      def get_winning_team
        if self.data[:wins]
          self.data[:wins].max[0]
        else
          "Neither Team"
        end
      end

      def end_match
        puts "Ending match..."
        begin
          self.data[:end] = Time.now

          self.data[:winner] = get_winning_team
          say "Match ended! #{self.data[:winner]} has won!"

          archive
          self.listener.kick_all
        rescue Exception => e
          puts e.message
          puts e.backtrace.join("\n")
        ensure
          puts "cease match"
          self.server.match.cease
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
            ready_threshold = _get_ready_threshold((self.players ? self.players.length : KAG::Config.instance[:match_size]))

            # if match is ready to go live, start it
            if self.ready.length == ready_threshold
              start

            # otherwise notify how many left are needed
            else
              say "Ready count now at #{self.ready.length.to_s} of #{ready_threshold.to_s} needed."
            end
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

      def evt_restart(msg)
        match = msg.match(/^(<)?(.{0,7}[ \.,\["\{\}><\|\/\(\)\\\+=])?([\w\._\-]{1,20})?(>) (?:!restart)$/)
        if match
          unless self.restart_queue.include?(match[3])
            restart_threshold = (self.players.length / 2).to_i
            self.restart_queue << match[3]
            if self.restart_queue.length == restart_threshold
              self.ready = []
              self.veto = []
              self.live = false
              self.listener.restart_map
            end
            say "Restart count now at #{self.restart_queue.length.to_s} of #{restart_threshold.to_s} needed."
            :restart
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
        self.listener.players.length
        self.listener.restart_map
        self.live = true
        self.restart_queue = []
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
        unless self.live
          say "Now in WARMUP mode. Please type !ready to begin the match."
        end
        :map_restart
      end
      def evt_round_started(msg)
        #broadcast "Match has started on #{self.server[:key]}"
        :match_start
      end
      def evt_round_ended(msg)
        self.data[:end] = Time.now
        self.ready = []
        self.veto = []
        :match_end
      end
      def evt_round_win(msg)
        self.live = false
        match = msg.match(/^(.+) (wins the game!)$/)
        if match
          self.data[:wins][match[1]] = 0 unless self.data[:wins][match[1]]
          self.data[:wins][match[1]] += 1

          say("Round has now ended. #{match[1]} team wins!")
          if _team_has_won
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

            # if in match, cancel sub request
            if self.live
              say "Back up to #{self.players_there.to_s} people of required #{self.players.length} in the match!"
            end
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

            # if in match, notify for sub
            if self.live
              say "Down to #{self.players_there.to_s} people of required #{self.players.length} in the match!"

              # check here to see if we're down to less than half, if so, then end match
              puts "Checking for match end threshold: #{self.players_there.to_s} < #{((self.players.length / 2)+1).to_s}"
              if self.players_there.to_i < ((self.players.length / 2)+1)
                end_match
              else
                # call for sub
                request_sub(player)
              end
            # otherwise, delete player from ready queue
            else
              self.ready.delete(player)
            end
          end
        end
        :player_left
      end
      def evt_player_chat(msg)
        :player_chat
      end

      def request_sub(player_left)

      end

      def swap_team(player)
        self.teams.each do |team|
          if team.players.include?(player.to_sym)
            self.listener.switch_team(player)
          end
        end
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
        record = self.data
        record[:server] = self.listener.server.key
        ts = []

        if self.listener.server.match.teams
          self.listener.server.match.teams.each do |team|
            ts << {:players => team.teammates,:color => team[:color],:name => team[:name]}

            # record user win/loss stats
            team.players.each do |authname,user|
              u = KAG::User::User.new(user)
              if team.teammates[authname.to_sym]
                stat = team.teammates[authname.to_sym].to_s.downcase+"_plays"
                u.add_stat(stat.to_sym)
              end
              if team[:name] == self.data[:winner]
                u.add_stat(:wins)
              else
                u.add_stat(:losses)
              end
              u.save
            end
          end
          record[:teams] = ts
        end
        record[:id] = self.listener.server.match[:id]
        record.delete(:bot) if record.key?(:bot)
        record.delete(:units_depleted)

        # record K/D for each user
        self.data.players.each do |player,data|
          user = SymbolTable.new({:authname => player,:nick => player})
          user = KAG::User::User.new(user)
          user.add_stat(:kills,data[:kill])
          user.add_stat(:deaths,data[:death])
        end

        KAG::Stats::Main.add_stat(:matches_completed)

        file = "data/matches/#{record[:id]}.json"
        unless File.exists?(file)
          File.open(file,"w") {|f| f.write(record.to_json) }
        end
        true
      end
    end
  end
end