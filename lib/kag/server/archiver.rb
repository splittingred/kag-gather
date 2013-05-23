require 'symboltable'
require 'kag/server/parser'

module KAG
  module Server
    class Archiver
      attr_accessor :data,:server,:log,:match
      def initialize(data,server,match,logger)
        self.data = data
        self.server = server
        self.log = logger
        self.match = match
      end

      def run
        self.log.info "- Attempting to archive match..."
        match = self.match
        if match
          match.stats = self.data.to_json
          match.save
        else
          self.log.error 'Could not find match to save stats to!'
        end

        self.log.info '- Archiving wins/losses'
        self.record_wins

        self.log.info '- Archiving k/d'
        self.record_kd

        KAG::Stats::Main.add_stat(:matches_completed)

        self.log.info '- Scoring all'
        begin
          ::User.rescore_all
          ::Clan.rescore_all
          ::Achievement.recalculate(match.users)
        rescue Exception => e
          self.log.error e.message
          self.log.error e.backtrace.join("\n")
        end

        self.log.info 'Finished archiving'
        true
      end

      def winning_team
        self.data[:wins].each do |team,wins|
          if wins >= 2
            return team
          end
        end
        false
      end

      def get_class(player)
        cls = false
        if self.data[:claims]
          if self.data[:claims].key?(player)
            cls = self.data[:claims][player].downcase
          end
        end
        cls
      end

      def teams
        if self.match
          self.match.teams
        else
          self.log.error 'COULD NOT FIND MATCH'
          false
        end
      end

      def record_wins
        winner = self.winning_team
        self.log.info "Winner was #{winner.to_s}."
        if winner
          teams = self.teams
          if teams
            teams.each do |team|
              # record user win/loss stats
              team.players.each do |player|
                if team.name == winner
                  player.won = true
                else
                  player.won = false
                end
                cls = get_class(player.user.kag_user)
                if cls
                  player.cls = cls.downcase
                else
                  self.log.error "No class for #{player.to_s}"
                end
                if player.save
                  user = player.user
                  if user
                    self.log.info "- Logging won/matches for #{user.name.to_s}"
                    k = player.won ? :wins : :losses
                    user.inc_stat(k)
                    user.set_stat('matches',user.stat('wins').to_i+user.stat('losses').to_i)

                    if cls
                      user.inc_stat(cls+'.'+k.to_s)
                      #user.inc_stat(cls+'.matches')
                      user.set_stat(cls+'.matches',user.stat(cls+'.wins').to_i+user.stat(cls+'.losses').to_i)
                    end


                    clan = user.clan
                    if clan
                      clan.inc_stat(k)
                      if cls
                        clan.inc_stat(cls+'.'+k.to_s)
                        clan.inc_stat(cls+'.matches')
                      end
                    end

                    self.log.info '-- Done!'
                  else
                    self.log.error "Cannot find User for player ID #{player.id}"
                  end
                else
                  self.log.error "Cannot save Player #{p.id} record!"
                end
              end
            end
          else
            self.log.error 'COULD NOT GET TEAMS in record_wins'
          end
        end
      end

      def record_kd
        # record K/D for each user
        self.data.players.each do |player,data|
          self.log.info "Attempting to record K/D for #{player.to_s}"
          p = ::Player.fetch_by_kag_user(player.to_s)
          if p
            self.log.info "- Found Player record with ID #{p.id}"
            p.kills = data[:kills].to_i
            p.deaths = data[:deaths].to_i
            if p.save
              user = p.user
              if user
                clan = user.clan
                cls = get_class(player.to_s)

                data.each do |stat,value|
                  user.inc_stat(stat,value)
                  if clan
                    clan.inc_stat(stat,value)
                  end
                end

                if cls
                  user.inc_stat(cls+'.kills',p.kills)
                  user.inc_stat(cls+'.deaths',p.deaths)

                  if clan
                    clan.inc_stat(cls+'.kills',p.kills)
                    clan.inc_stat(cls+'.deaths',p.deaths)
                  end
                end

                self.log.info "Scoring #{user.name} to : #{user.score.to_s}"
              else
                self.log.error "Cannot find User for player ID #{p.id}"
              end
            else
              self.log.error "Cannot save Player #{p.id} record!"
            end
          else
            self.log.error "Could not find Player with kag_user #{player.to_s} for stats archiving!"
          end
        end
      end

      def record_kills
        self.data.kills.each do |k,record|
          killer = ::User.find_by_kag_user(k)
          if killer and record.respond_to?(:each)
            record.each do |victim,times|
              killer.add_kill(victim,times)
            end
          end
        end
      end

    end
  end
end