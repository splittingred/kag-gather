require 'symboltable'
require 'kag/stats/main'
require 'kag/user/user'
require 'kag/server/archiver'

# Stuff left to add:
# * COLLAPSE by [Clan] nickname (size X blocks)
#

module KAG
  module Server
    class Parser
      attr_accessor :server,:log,:data,:live,:ready,:veto,:listener,:restart_queue
      attr_accessor :units_depleted,:players_there,:sub_requests,:test
      attr_accessor :players,:teams,:match

      def initialize(listener,data)
        self.server = listener.server
        self.log = listener.log
        self.listener = listener
        self.ready = []
        self.veto = []
        self.restart_queue = []
        self.match = self.server.match_in_progress
        self.teams = self.server.match_in_progress.teams
        self.test = false
        ps = []
        self.server.match_in_progress.users.each do |u|
          ps << u.name
        end
        self.players = ps
        self.players_there = 0
        self.sub_requests = {}
        self.data = data.merge({
          :units_depleted => false,
          :wins => {},
          :match_start => Time.now,
          :match_end => nil,
          :players => {},
          :started => false,
        })
        self.players.each do |p|
          self.data[:players][p.to_s] = {}
        end
        self.live = false
      end
      def parse(msg)
        return false if msg.to_s.empty? or msg.to_s.length < 11
        msg = msg[11..msg.length]

        self.log.info((self.live ? '[LIVE] ' : '[WARMUP] ')+msg.to_s)
        puts (self.live ? '[LIVE] ' : '[WARMUP] ')+msg.to_s if self.test

        if msg.index('*Restarting Map*')
          self.evt_map_restart(msg)
        elsif msg.index(/^(.{0,6}[ \.,\["\{\}><\|\/\(\)\\\+=])?([\S]{1,20}) (?:is now known as) (.{0,6}[ \.,\["\{\}><\|\/\(\)\\\+=])?([\S]{1,20})$/)
          self.evt_player_renamed(msg)
        elsif msg.index(/^Unnamed player is now known as (.{0,6}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20})$/)
          self.evt_player_join_renamed(msg)
        elsif msg.index(/^(?:Player) (.{0,7}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) (?:left the game \(players left [0-9]+\))$/)
          self.evt_player_left(msg)
        elsif msg.index("!request_sub") or msg.index("!rsub")
          self.evt_request_sub(msg)
        elsif msg.index('!score')
          self.evt_score(msg)
        elsif msg.index('!teams')
          self.evt_teams(msg)
        elsif msg.index('!players')
          self.evt_players(msg)
        elsif msg.index('!team')
          self.evt_team(msg)
        elsif msg.index('!nerf')
          self.evt_nerf(msg)
        elsif msg.index('!claimed')
          self.evt_claimed(msg)
        elsif msg.index('!say') or !msg.index('@').nil?
          self.evt_say(msg)

        elsif self.live # live mode
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
            self.evt_restart(msg)
          end
        else # warmup
          if msg.match(/^(<)?(.{0,7}[ \.,\["\{\}><\|\/\(\)\\\+=])?([\w\._\-]{1,20})?(>) (?:!ready (.*))$/i)
            self.evt_ready_specified(msg)
          elsif msg.index("!ready")
            self.evt_ready(msg)
          elsif msg.index("!unready")
            self.evt_unready(msg)
          elsif msg.index("!who_ready") or msg.index('!wr')
            self.evt_who_ready(msg)
          elsif msg.index("!who_not_ready") or msg.index('!wnr')
            self.evt_who_not_ready(msg)
          elsif msg.index("!veto")
            self.evt_veto(msg)
          elsif msg.index("!hello")
            self.evt_hello(msg)
          elsif msg.index("!claim")
            self.evt_claim(msg)
          elsif msg.index("!unclaim")
            self.evt_unclaim(msg)
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
          'Neither Team'
        end
      end

      def end_match
        self.log.info 'Ending match...'
        begin
          self.data[:end] = Time.now
          self.data[:winner] = get_winning_team
          say "Match ended! #{self.data[:winner]} has won!"

          #self.archive
          #self.listener.kick_all unless self.test
          self.log.info 'finished match, quitting'
          true
        rescue Exception => e
          self.log.error e.message
          self.log.error e.backtrace.join("\n")
        ensure
          self.log.info "cease match"
          self.match.cease
        end
      end

      def broadcast(msg)
        if self.test
          puts msg
        else
          if KAG::Config.instance[:channels] and self.server and KAG.gather.bot
            KAG::Config.instance[:channels].each do |c|
              channel = KAG.gather.bot.channel_list.find_ensured(c)
              if channel
                channel.send(msg)
              end
            end
          end
        end
      end

      def evt_score(msg)
        say _get_score
        :score
      end

      def _get_score
        if self.data[:wins] and self.data[:wins].length > 0
          txt = []
          if self.data[:wins].length == 1
            self.data[:wins].keys.first == "Blue Team" ? self.data[:wins]["Red Team"] = 0 : self.data[:wins]["Blue Team"] = 0
          end
          self.data[:wins].each do |team,score|
            txt << "#{team.to_s}: #{score.to_s}"
          end
          txt.join(", ")
        else
          "Red Team: 0, Blue Team: 0"
        end
      end

      def evt_ready(msg)
        match = msg.match(/^(<)?(.{0,7}[ \.,\["\{\}><\|\/\(\)\\\+=])?([\w\._\-]{1,20})?(>) (?:!ready)$/)
        if match
          if self.ready.include?(match[3])
            say "You are already ready, #{match[3]}!"
            nil
          else
            say "#{match[3]}, please specify a class via !ready [classname]"
            :ready
          end
        end
      end

      def evt_ready_specified(msg)
        match = msg.match(/^(<)?(.{0,7}[ \.,\["\{\}><\|\/\(\)\\\+=])?([\w\._\-]{1,20})?(>) (?:!ready (.*))$/i)
        if match
          username = match[3].to_s.strip
          if self.ready.include?(username)
            say "You are already ready, #{username}!"
            nil
          else
            player_class = match[5].to_s.strip.downcase.capitalize
            unless username.empty? or player_class.empty?
              if %w(Archer Knight Builder).include?(player_class)
                team = get_team(username)

                self.data[:claims] = {} unless self.data[:claims]
                self.data[:claims][username] = player_class
                self.ready << username
                say "#{username} is ready and has claimed #{player_class} for: #{team}."

                ready_threshold = _get_ready_threshold((self.players ? self.players.length : KAG::Config.instance[:match_size]))

                # if match is ready to go live, start it
                if self.ready.length == ready_threshold
                  start
                # otherwise notify how many left are needed
                else
                  say "Ready count now at #{self.ready.length.to_s} of #{ready_threshold.to_s} needed."
                end
                :ready
              else
                say "#{username}, #{player_class} is not a valid class."
              end
            end
          end
        end
      end

      def evt_unready(msg)
        match = msg.match(/^(<)?(.{0,7}[ \.,\["\{\}><\|\/\(\)\\\+=])?([\w\._\-]{1,20})?(>) (?:!unready)$/)
        if match
          if self.ready.include?(match[3])
            self.ready.delete(match[3])
            ready_threshold = _get_ready_threshold((self.players ? self.players.length : KAG::Config.instance[:match_size]))

            say "Ready count now at #{self.ready.length.to_s} of #{ready_threshold.to_s} needed."
            :unready
          else
            say "You were never ready, #{match[3]}!"
          end
        end
      end

      def evt_who_ready(msg)
        say 'Ready: '+self.ready.join(", ")
        :who_ready
      end

      def evt_who_not_ready(msg)
        say 'Not Ready: '+(self.players - self.ready).join(', ')
        :who_not_ready
      end

      def _get_ready_threshold(num_of_players)
        #half = (num_of_players / 2)
        #half + (half / 2).ceil
        num_of_players.to_i == 2 ? 1 : num_of_players
      end

      def evt_teams(msg)
        say self.match.teams_text
        :teams
      end

      def evt_team(msg)
        match = msg.match(/^(<)?(.{0,7}[ \.,\["\{\}><\|\/\(\)\\\+=])?([\w\._\-]{1,20})?(>) (?:!team)$/)
        if match
          username = match[3].to_s.strip
          say "#{username} is on: #{get_team(username)}"
        end
      end

      def get_team(username)
        t = 'Spectator'
        self.teams.each do |team|
          if team.has_player?(username)
            t = team.name
          end
        end
        t
      end

      def evt_veto(msg)
        m = msg.match(/^(<)?(.{0,7}[ \.,\["\{\}><\|\/\(\)\\\+=])?([\w\._\-]{1,20})?(>) (?:!veto)$/)
        if m
          username = m[3].to_s.strip
          if self.veto.include?(username)
            say "You have already voted to veto the map, #{username}!"
          else
            if self.players
              veto_threshold = (self.players.length / 2).to_i
            else
              veto_threshold = (KAG::Config.instance[:veto_threshold] or 5)
            end
            self.veto << username
            if self.veto.length >= veto_threshold
              self.listener.next_map unless self.test
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
          if self.restart_queue.include?(match[3])
            say "You have already voted for a restart, #{match[3]}!"
          else
            restart_threshold = (self.players.length / 2).to_i
            self.restart_queue << match[3]
            if self.restart_queue.length >= restart_threshold
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

      def evt_say(msg)
        match = msg.match(/^(<)?(.{0,7}[ \.,\["\{\}><\|\/\(\)\\\+=])?([\w\._\-]{1,20})?(>) (?:!say) (.*)$/)
        match = msg.match(/^(<)?(.{0,7}[ \.,\["\{\}><\|\/\(\)\\\+=])?([\w\._\-]{1,20})?(>) (?:\@)(.*)$/) if match.nil?
        if match
          user = match[2].to_s.strip+' '+match[3].to_s.strip
          msg = match[5].to_s.strip
          broadcast('<'+user+'@'+self.server.name+'> '+msg)
          :say
        end
      end

      ##
      # Handle !rsub commands
      #
      def evt_request_sub(msg)
        m = msg.match(/^(<)?(.{0,7}[ \.,\["\{\}><\|\/\(\)\\\+=])?([\w\._\-]{1,20})?(>) (?:!(?:rsub|request_sub) (.*))$/)
        if m
          player_to_sub = m[5].strip.to_s
          player_requesting = m[3].strip.to_s
          self.sub_requests[player_to_sub] = [] unless self.sub_requests[player_to_sub]
          if already_sub_requested?(player_to_sub,player_requesting)
            say "You can only vote to request a sub for that person once, #{player_requesting}."
          #elsif !can_sub_request?(player_to_sub,player_requesting)
          #  say "You cannot request a sub for the other team, #{player_requesting}."
          else
            self.sub_requests[player_to_sub] << player_requesting
            votes_needed = (self.players.length / 4).to_i
            if self.sub_requests[player_to_sub].length > votes_needed
              match_in_progress = self.match
              if match_in_progress
                substitution = match_in_progress.request_sub(m[5].strip)
                if substitution
                  self.listener.kick(m[5]) unless self.test
                  if substitution.old_player and substitution.old_player.user and !substitution.old_player.user.kag_user.nil? and !substitution.old_player.user.kag_user.empty?
                    self.listener.kick(substitution.old_player.user.kag_user.to_s) unless self.test
                  end
                  say "Sub requested for #{m[5].to_s}. Please stand by."
                  :request_sub
                else
                  say "Cannot find the User #{m[5].to_s}. Try the person\'s authname or KAG account name instead."
                end
              end
            else
              say "Sub request for #{player_to_sub} made. #{votes_needed.to_s} more votes needed."
              :request_sub
            end
          end
        end
      end

      def already_sub_requested?(player_to_sub,player_requesting)
        self.sub_requests[player_to_sub].include?(player_requesting)
      end

      def can_sub_request?(subbee,requestor)
        subbee_player = ::Player.fetch_by_kag_user(subbee)
        requestor_player = ::Player.fetch_by_kag_user(requestor)
        if requestor_player and subbee_player
          subbee_player.team_id == requestor_player.team_id
        else
          false
        end
      end

      def evt_nerf(msg)
        m = msg.match(/^(<)?(.{0,7}[ \.,\["\{\}><\|\/\(\)\\\+=])?([\w\._\-]{1,20})?(>) (?:!nerf (.*))$/)
        if m
          if m[3].to_s.strip == "splittingred"
            t = m[5].to_s.strip
            say "Nerfing... #{t} was too OP anyway."
          end
        end
      end

      def evt_claim(msg)
        m = msg.match(/^(<)?(.{0,7}[ \.,\["\{\}><\|\/\(\)\\\+=])?([\w\._\-]{1,20})?(>) (?:!claim (.*))$/)
        if m
          username = m[3].to_s.strip
          player_class = m[5].to_s.strip.downcase.capitalize
          unless username.empty? or player_class.empty?
            if ['Archer','Knight','Builder'].include?(player_class)
              team = get_team(username)

              self.data[:claims] = {} unless self.data[:claims]
              self.data[:claims][username] = player_class
              say "#{username} has claimed #{player_class} for: #{team}."
              :claim
            else
              say "#{username}, #{player_class} is not a valid class."
            end
          end
        end
      end

      def evt_unclaim(msg)
        m = msg.match(/^(<)?(.{0,7}[ \.,\["\{\}><\|\/\(\)\\\+=])?([\w\._\-]{1,20})?(>) (?:!unclaim)$/)
        if m
          username = m[3].to_s.strip
          unless username.empty?
            self.data[:claims] = {} unless self.data[:claims]
            if self.data[:claims].key?(username)
              self.data[:claims].delete(username)
              say "#{username} class claim removed."
              :unclaim
            end
          end
        end
      end

      def evt_claimed(msg)
        if self.data
          self.data[:claims] = [] unless self.data.key?(:claims)
          list = []
          self.data[:claims].each do |username,player_class|
            list << "#{username}: #{player_class}"
          end
          say "Claimed: "+list.join(", ")
          :claimed
        end
      end

      def start
        #self.listener.players.length
        self.listener.restart_map unless self.test
        self.live = true
        self.restart_queue = []
        self.units_depleted = false
        say "Round is now LIVE!"
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
        :round_start
      end
      def evt_round_ended(msg)
        self.data[:end] = Time.now
        self.ready = []
        self.veto = []
        :round_end
      end
      def evt_round_win(msg)
        self.live = false
        match = msg.match(/^(.+) (wins the game!)$/)
        if match
          winner = match[1].to_s.strip
          self.data[:wins][winner] = 0 unless self.data[:wins][winner]
          self.data[:wins][winner] += 1

          say "Round has now ended. #{winner} wins!"
          if _team_has_won
            end_match unless self.test
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
              self.log.info "Checking for match end threshold: #{self.players_there.to_s} < #{((self.players.length / 2)+1).to_s}"
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

      def evt_players(msg)
        say 'Players: '+self.players.join(', ')
      end

      def sub_in(old_user,new_user,team)
        msg = "#{new_user.name} has subbed for #{old_user.name} for the #{team.name}!"
        say msg.to_s
        self.players.delete(old_user.name)
        self.players << new_user.name
      end

      def request_sub(player_left)

      end

      def swap_team(player)
        self.teams.each do |team|
          if team.players.include?(player.to_sym)
            self.listener.switch_team(player) unless self.test
          end
        end
      end

      def evt_kill(msg)
        # slew
        if (match = msg.match(/^(.{0,6}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) slew (.{0,6}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) with (?:his|her) sword$/))
          _add_stat(:kill,match[2])
          _add_kill_type(:slew,match[2])
          _add_stat(:death,match[4])
          _add_death_type(:slew,match[4])
          :slew

        # gibbed
        elsif (match = msg.match(/^(.{0,6}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) gibbed (.{0,6}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20})? into pieces$/))
          _add_stat(:kill,match[2])
          _add_kill_type(:gibbed,match[2])
          if !match[4].nil? and !match[4].to_s.empty?
            _add_stat(:death,match[4])
            _add_death_type(:gibbed,match[4])
          end
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

      def archive
        a = Archiver.new(self.data,self.listener.server,self.match,self.log)
        a.run
      end

      private

      def say(msg)
        if self.test
          self.log.info "[SAY] #{msg}"
        else
          self.listener.msg(msg) if self.listener and self.listener.respond_to?(:msg)
        end
      end

      def _add_stat(stat,player,increment = 1)
        return false if (player.nil? or stat.nil?)
        stat = stat.to_sym
        player = player.to_s
        self.data[:players] = {} unless self.data.players
        if self.data.players
          self.data.players[player] = {} unless self.data.players[player]
          self.data.players[player][stat] = 0 unless self.data.players[player][stat]
          self.data.players[player][stat] = self.data.players[player][stat] + increment.to_i
          self.data.players[player][stat]
        end
      end

      def _add_kill_type(type,player,increment = 1)
        return false if (player.nil? or type.nil?)
        type = type.to_sym
        player = player.to_s
        self.data[:players] = {} unless self.data.players
        if self.data.players
          self.data.players[player] = {} unless self.data.players[player]
          self.data.players[player][:kill_types] = {} unless self.data.players[player][:kill_types]
          self.data.players[player][:kill_types][type] = 0 unless self.data.players[player][:kill_types][type]
          self.data.players[player][:kill_types][type] = self.data.players[player][:kill_types][type] + increment.to_i
        end
      end

      def _add_death_type(type,player,increment = 1)
        return false if (player.nil? or type.nil?)
        type = type.to_sym
        player = player.to_s
        self.data[:players] = {} unless self.data.players
        if self.data.players
          self.data.players[player] = {} unless self.data.players[player]
          self.data.players[player][:death_types] = {} unless self.data.players[player][:death_types]
          self.data.players[player][:death_types][type] = 0 unless self.data.players[player][:death_types][type]
          self.data.players[player][:death_types][type] = self.data.players[player][:death_types][type] + increment.to_i
        end
      end

    end
  end
end