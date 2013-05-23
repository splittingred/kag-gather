require 'symboltable'
require 'kag/eventable'
require 'kag/stats/main'
require 'kag/user/user'
require 'kag/server/archiver'

# Stuff left to add:
# * COLLAPSE by [Clan] nickname (size X blocks)
#

module KAG
  module Server
    class Parser
      include KAG::Eventable

      attr_accessor :server,:log,:data,:live,:ready,:veto,:listener,:restart_queue
      attr_accessor :units_depleted,:players_there,:sub_requests,:test
      attr_accessor :players,:teams,:match
      attr_accessor :killstreaks,:deathstreaks,:clans

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
        self.killstreaks = {}
        self.deathstreaks = {}
        self.clans = {}
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

      event :evt_map_restart, '*Restarting Map*'
      event :evt_player_renamed, /^(.{0,6}[ \.,\["\{\}><\|\/\(\)\\\+=])?([\S]{1,20}) (?:is now known as) (.{0,6}[ \.,\["\{\}><\|\/\(\)\\\+=])?([\S]{1,20})$/
      event :evt_player_join_renamed, /^Unnamed player is now known as (.{0,6}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20})$/
      event :evt_player_left, /^(?:Player) (.{0,7}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) (?:left the game \(players left [0-9]+\))$/
      event :evt_request_sub, %w(!request_sub !rsub)
      event :evt_score, '!score'
      event :evt_teams, '!teams'
      event :evt_team, '!team'
      event :evt_players, '!players'
      event :evt_say, %w(!say @)
      event :evt_hello, '!hello'
      event :evt_nerf, '!nerf'

      event :evt_round_win, /^(.+) (wins the game!)$/, :live
      event :evt_kill, /^(.+) (slew|gibbed|shot|hammered|pushed|assisted|squashed|fell|took|died) (.+)$/, :live
      event :evt_units_depleted, "Can't spawn units depleted", :live
      event :evt_round_started, '*Match Started*', :live
      event :evt_round_ended, '*Match Ended*', :live
      event :evt_restart, '!restart', :live

      event :evt_ready_specified, [/^(<)?(.{0,7}[ \.,\["\{\}><\|\/\(\)\\\+=])?([\w\._\-]{1,20})?(>) (?:!ready (.*))$/i,/^(<)?(.{0,7}[ \.,\["\{\}><\|\/\(\)\\\+=])?([\w\._\-]{1,20})?(>) (?:!r (.*))$/i], :warmup
      event :evt_ready, %w(!ready !r), :warmup
      event :evt_unready, %w(!unready !ur), :warmup
      event :evt_who_ready, %w(!who_ready !wr), :warmup
      event :evt_who_not_ready, %w(!who_not_ready !wnr), :warmup
      event :evt_veto, '!veto', :warmup
      event :evt_force_start, '!force_start', :warmup

      def parse(msg)
        return false if msg.to_s.empty? or msg.to_s.length < 11
        msg = msg[11..msg.length].strip

        self.check_for_clan(msg) unless self.live

        self.log.info((self.live ? '[LIVE] ' : '[WARMUP] ')+msg.to_s)
        puts (self.live ? '[LIVE] ' : '[WARMUP] ')+msg.to_s if self.test

        self.process_event(msg)
      end

      def is_admin?(username)
        o = (KAG::Config.instance[:owners] or [])
        o.include?(username)
      end

      def check_for_clan(msg)
        match = msg.match(/^(<)?(.{0,7}[ \.,\["\{\}><\|\/\(\)\\\+=])?([\w\._\-]{1,20})?(>) (?:.*)/i)
        if match
          if !match[2].to_s.empty? and !match[3].to_s.empty?
            clan_name = match[2].to_s.strip
            unless self.clans.keys.include?(clan_name)
              self.clans[clan_name.to_s] = {}
            end
            if self.clans[clan_name.to_s]
              self.clans[clan_name.to_s][:obj] = ::Clan.fetch(clan_name) unless self.clans[clan_name.to_s][:obj].class == ::Clan
              if self.clans[clan_name.to_s][:obj]
                self.clans[clan_name.to_s][:obj].add_member(match[3])
              end
            end
          end
        end
      end

      def _team_has_won
        self.data[:wins].each do |team,wins|
          if wins >= 2
            self.data[:winner] = team
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
          broadcast "Match #{self.match.id} finished! #{self.data[:winner]} has won!"

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
          txt.join(', ')
        else
          'Red Team: 0, Blue Team: 0'
        end
      end

      def evt_ready(msg)
        match = msg.match(/^(<)?(.{0,7}[ \.,\["\{\}><\|\/\(\)\\\+=])?([\w\._\-]{1,20})?(>) (?:!ready)$/)
        if match
          username = match[3].to_s.strip
          if self.ready.include?(username)
            say "You are already ready, #{username}!"
            nil
          else
            say "#{username}, please specify a class via !ready [classname]"
            :ready
          end
        end
      end

      def evt_ready_specified(msg)
        match = msg.match(/^(<)?(.{0,7}[ \.,\["\{\}><\|\/\(\)\\\+=])?([\w\._\-]{1,20})?(>) (?:!ready (.*))$/i)
        match = msg.match(/^(<)?(.{0,7}[ \.,\["\{\}><\|\/\(\)\\\+=])?([\w\._\-]{1,20})?(>) (?:!r (.*))$/i) if match.nil?
        if match
          username = match[3].to_s.strip
          player_class = match[5].to_s.strip.downcase.capitalize
          unless username.empty? or player_class.empty?
            if %w(Archer Knight Builder).include?(player_class)
              team = get_team(username)

              self.data[:claims] = {} unless self.data[:claims]
              self.data[:claims][username] = player_class

              if self.ready.include?(username)
                say "#{username} has switched to #{player_class} for: #{team}."
              else
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
              end
              :ready
            else
              say "#{username}, #{player_class} is not a valid class."
            end
          end
        end
      end

      def evt_force_start(msg)
        match = msg.match(/^(<)?(.{0,7}[ \.,\["\{\}><\|\/\(\)\\\+=])?([\w\._\-]{1,20})?(>) (?:!force_start)$/)
        if match
          username = match[3].to_s.strip
          if is_admin?(username)
            start
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

      def get_class(username)
        cls = ''
        if self.data.key?(:claims) and self.data[:claims].key?(username)
          cls = self.data[:claims][username]
        end
        cls
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
            restart_threshold = (self.players.length / 2).to_i + 1
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
          if self.players.include?(player_to_sub)
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
                  substitution = match_in_progress.request_sub(player_to_sub)
                  if substitution
                    self.listener.kick(player_to_sub) unless self.test
                    if substitution.old_player and substitution.old_player.user and !substitution.old_player.user.kag_user.nil? and !substitution.old_player.user.kag_user.empty?
                      self.listener.kick(substitution.old_player.user.kag_user.to_s) unless self.test
                    end
                    say "Sub requested for #{player_to_sub}. Please stand by."
                    :request_sub
                  else
                    say "Cannot find the User #{player_to_sub}. Try the person\'s authname or KAG account name instead."
                  end
                end
              else
                say "Sub request for #{player_to_sub} made. #{votes_needed.to_s} more votes needed."
                :request_sub
              end
            end
          else
            say "You cannot request a sub for a player not in the match, #{player_requesting}."
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
          username = m[3].to_s.strip
          if is_admin?(username)
            t = m[5].to_s.strip
            say "Nerfing... #{t} was too OP anyway."
          end
        end
      end

      def start
        #self.listener.players.length
        self.listener.restart_map unless self.test
        self.live = true
        self.restart_queue = []
        self.units_depleted = false
        say 'Round is now LIVE!'
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
          say 'Now in WARMUP mode. Please type !ready to begin the match.'
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
          say 'Score is now: '+_get_score
          if _team_has_won
            end_match unless self.test
          else
            begin
              broadcast "#{winner} has won a round on match #{self.match.id}. Score: #{_get_score}"
            end
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
          _add_kill(match[3],match[4],match[1],match[2],:slew)
          :slew

        # gibbed
        elsif (match = msg.match(/^(.{0,6}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) gibbed (.{0,6}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20})? into pieces$/))
          victim = (!match[4].nil? and !match[4].to_s.empty? ? match[4] : nil)
          victim_clan = (!match[3].nil? and !match[3].to_s.empty? ? match[3] : nil)
          _add_kill(victim_clan,victim,match[1],match[2],:gibbed)
          :gibbed

        # shot
        elsif (match = msg.match(/^(.{0,6}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) shot (.{0,6}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) with (?:his|her) arrow$/))
          _add_kill(match[3],match[4],match[1],match[2],:shot)
          :shot

        # hammered
        elsif (match = msg.match(/^(.{0,6}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) hammered (.{0,6}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) to death$/))
          _add_kill(match[3],match[4],match[1],match[2],:hammered)
          :hammered

        # pushed
        elsif (match = msg.match(/^(.{0,6}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) pushed (.{0,6}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) (?:on a spike trap|to his death)$/))
          _add_kill(match[3],match[4],match[1],match[2],:pushed)
          :pushed

        # assisted
        elsif (match = msg.match(/^(.{0,6}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) assisted in(?: squashing)? (.{0,6}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20})(?: dying)? under (?:a collapse|falling rocks)$/))
          victim = (match[4].strip == 'dying' ? match[3] : match[4])
          victim_clan = (match[4].strip == 'dying' ? match[2] : match[3])
          _add_kill(victim_clan,victim,match[1],match[2],:assisted)
          :assisted

        # squashed
        elsif (match = msg.match(/^(.{0,6}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) was squashed under a collapse$/))
          _add_kill(match[1],match[2],nil,:squashed)
          :squashed

        # fell
        elsif (match = msg.match(/^(.{0,6}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) fell (?:(?:to (?:his|her) death)|(?:on a spike trap))$/))
          _add_kill(match[1],match[2],nil,:fell)
          :fell

        # cyanide
        elsif (match = msg.match(/^(.{0,6}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) took some cyanide$/))
          _add_kill(match[1],match[2],nil,:cyanide)
          :cyanide

        # died
        elsif (match = msg.match(/^(.{0,6}[ \.,\["\{\}><\|\/\(\)\\+=])?([\S]{1,20}) died under falling rocks$/))
          _add_kill(match[1],match[2],nil,:died)
          :died
        else
          :unknown
        end
      end

      def _add_kill(victim_clan = nil,victim = nil,killer_clan = nil,killer = nil,type = :unknown)
        killstreak_threshold = KAG::Config.instance[:killstreak].to_i
        deathstreak_threshold = KAG::Config.instance[:deathstreak].to_i
        unless victim.nil?
          victim = victim.to_s.strip
          if self.killstreaks[victim].to_i > 0
            if self.killstreaks[victim] >= killstreak_threshold # if they're on a killstreak
              if killer.nil? # died without killer
                say "#{victim}'s killstreak was ended at #{self.killstreaks[victim].to_s}"
              else # killed by someone else
                say "#{killer.to_s.strip} ended #{victim}'s killstreak of #{self.killstreaks[victim].to_s}"
                self._add_stat(:ended_others_killstreak,killer_clan,killer)
              end
            end
            self.killstreaks[victim] = 0
          end

          victim = victim.to_s.strip
          if self.deathstreaks.key?(victim)
            self.deathstreaks[victim] += 1
          else
            self.deathstreaks[victim] = 1
          end

          if self.deathstreaks[victim] == deathstreak_threshold
            say "#{victim} is on a death streak!"
            self._add_stat(:deathstreaks,victim_clan,victim)
          end

          _add_stat(:deaths,victim_clan,victim)
          _add_stat('deaths.'+type.to_s,victim_clan,victim)
        end

        unless killer.nil?
          killer = killer.to_s.strip
          if self.killstreaks.key?(killer)
            self.killstreaks[killer] += 1
          else
            self.killstreaks[killer] = 1
          end

          if self.killstreaks[killer] == killstreak_threshold
            say "#{killer} is on a kill streak!"
            self._add_stat(:killstreaks,killer_clan,killer)
          elsif self.killstreaks[killer] == 10
            say "#{killer} is on a 10 kill streak! Wow!"
            self._add_stat(:killstreak_10,killer_clan,killer)
            cls = get_class(killer).downcase.capitalize
            if cls == 'Builder'
              self._add_stat(:bloody_hammer,killer_clan,killer)
            end
          elsif self.killstreaks[killer] == 20
            say "#{killer} is on a 20 kill streak! Hot!"
            self._add_stat(:killstreak_20,killer_clan,killer)
            cls = get_class(killer).downcase.capitalize
            if cls == 'Archer'
              self._add_stat(:dead_eye,killer_clan,killer)
            end
          elsif self.killstreaks[killer] == 30
            say "#{killer} is on a 30 kill streak! OMG run away!"
            self._add_stat(:killstreak_30,killer_clan,killer)
            cls = get_class(killer).downcase.capitalize
            if cls == 'Knight'
              self._add_stat(:excalibur,killer_clan,killer)
            end
          end

          if self.deathstreaks[killer].to_i > 0
            if self.deathstreaks[killer] >= deathstreak_threshold # if they're on a deathstreak
              if victim.nil? # killed without victim
                say "#{killer}'s deathstreak was ended at #{self.deathstreaks[killer].to_s}"
              else # killed someone else
                say "#{victim} ended #{killer}'s deathstreak of #{self.deathstreaks[killer].to_s}"
                self._add_stat(:ended_others_deathstreak,victim_clan,victim)
              end
            end
            self.deathstreaks[killer] = 0
          end

          _add_stat(:kills,killer_clan,killer)
          _add_stat('kills.'+type.to_s,killer_clan,killer)
          if !killer.nil? and !victim.nil?
            _add_kill_record(killer,victim)
          end
        end
      end

      def archive
        a = Archiver.new(self.data,self.listener.server,self.match,self.log)
        a.run
      end

      protected

      def _add_kill_record(killer,victim)
        self.data[:kills] = {} unless self.data.key?(:kills)
        self.data[:kills][killer.to_s] = {} unless self.data[:kills].key?(killer.to_s)
        self.data[:kills][killer.to_s][victim.to_s] = 0 unless self.data[:kills][killer.to_s].key?(victim.to_s)
        self.data[:kills][killer.to_s][victim.to_s] += 1
      end

      def say(msg)
        if self.test
          puts "[SAY] #{msg}"
        else
          self.listener.msg(msg) if self.listener and self.listener.respond_to?(:msg)
        end
      end

      def _add_stat(stat,clan,player,increment = 1)
        return false if (player.nil? or stat.nil?)
        stat = stat.to_sym
        player = player.to_s
        clan = clan.to_s
        self.data[:clans] = {} unless self.data.clans
        self.data[:players] = {} unless self.data.players
        if self.data.players
          self.data.players[player] = {} unless self.data.players[player]
          self.data.players[player][stat] = 0 unless self.data.players[player][stat]
          self.data.players[player][stat] = self.data.players[player][stat] + increment.to_i
          self.data.players[player][stat]
        end
        if self.data.clans
          self.data.clans[clan] = {} unless self.data.clans[clan]
          self.data.clans[clan][stat] = 0 unless self.data.clans[clan][stat]
          self.data.clans[clan][stat] = self.data.clans[clan][stat] + increment.to_i
          self.data.clans[clan][stat]
        end
      end

    end
  end
end