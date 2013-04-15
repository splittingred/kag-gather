require 'symboltable'
require 'kag/server/parser'

module KAG
  module Server
    class Archiver
      attr_accessor :data,:server
      def initialize(data,server)
        self.data = data
        self.server = server
      end


      def process
        self.record_wins
        self.record_kd

        match = self.match
        if match
          match.stats = self.data.to_json
          match.save
        else
          puts "Could not find match to save stats to!"
        end

        KAG::Stats::Main.add_stat(:matches_completed)
      end

      def winning_team
        self.data[:wins].each do |team,wins|
          if wins >= 2
            return team
          end
        end
        false
      end


      def match
        self.server.match
      end

      def teams
        self.server.match.teams
      end

      def record_wins
        winner = self.winning_team
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
              if player.save
                user = player.user
                if user
                  k = player.won ? :wins : :losses
                  user.inc_stat(k)
                else
                  puts "Cannot find User for player ID #{player.id}"
                end
              else
                puts "Cannot save Player #{p.id} record!"
              end
            end
          end
        end
      end

      def record_kd
        # record K/D for each user
        self.data.players.each do |player,data|
          p = ::Player.fetch_by_kag_user(player.to_s)
          if p
            p.kills = data[:kill]
            p.deaths = data[:death]
            if p.save
              user = p.user
              if user
                user.inc_stat(:kills,p.kills)
                user.inc_stat(:deaths,p.deaths)
                if data[:death_types]
                  data[:death_types].each do |type,v|
                    user.inc_stat("deaths."+type.to_s,v)
                  end
                end
                if data[:kill_types]
                  data[:kill_types].each do |type,v|
                    user.inc_stat("kills."+type.to_s,v)
                  end
                end
              else
                puts "Cannot find User for player ID #{p.id}"
              end
            else
              puts "Cannot save Player #{p.id} record!"
            end
          else
            puts "Could not find Player with kag_user #{player.to_s} for stats archiving!"
          end
        end
      end

    end
  end
end