require 'symboltable'
require 'kag/server/parser'

module KAG
  module Server
    class Archiver
      attr_accessor :data,:server,:log
      def initialize(data,server,logger)
        self.data = data
        self.server = server
        self.log = logger
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

      def match
        self.server.match
      end

      def teams
        self.server.match.teams
      end

      def record_wins
        winner = self.winning_team
        puts "Winner was #{winner.to_s}."
        if winner
          teams = self.teams
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
                  if cls
                    user.inc_stat(cls+'.'+k.to_s)
                    user.inc_stat(cls+'.matches')
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
        end
      end

      def record_kd
        # record K/D for each user
        self.data.players.each do |player,data|
          self.log.info "Attempting to record K/D for #{player.to_s}"
          p = ::Player.fetch_by_kag_user(player.to_s)
          if p
            self.log.info "- Found Player record with ID #{p.id}"
            p.kills = data[:kill]
            p.deaths = data[:death]
            if p.save
              user = p.user
              if user
                self.log.info "- Logging K/D for User #{user.kag_user}"
                user.inc_stat(:kills,p.kills)
                user.inc_stat(:deaths,p.deaths)
                if data[:death_types]
                  data[:death_types].each do |type,v|
                    user.inc_stat('deaths.'+type.to_s,v)
                  end
                end
                if data[:kill_types]
                  data[:kill_types].each do |type,v|
                    user.inc_stat('kills.'+type.to_s,v)
                  end
                end

                cls = get_class(player.to_s)
                if cls
                  user.inc_stat(cls+'.kills',p.kills)
                  user.inc_stat(cls+'.deaths',p.deaths)
                end
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

    end
  end
end