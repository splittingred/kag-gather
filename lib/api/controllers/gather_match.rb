require 'api/controllers/base'
module KAG
  module API
    module Controller
      class Gather_match < Base
        @class_key = 'Match'
        @primary_key = 'id'

        def read(id)
          match = ::Match.find(id)
          if match
            data = match.attributes
            if match.stats
              data[:stats] = JSON.parse(match.stats)
              data[:stats].delete(:units_depleted)

              data[:teams] = {}
              match.teams.each do |team|
                players = {}
                team.users.each do |user|
                  if data[:stats].key?('claims')
                    cls = data[:stats]['claims'].key?(user.kag_user) ? data[:stats]['claims'][user.kag_user] : ''
                  else
                    cls = ''
                  end

                  kills = 0
                  deaths = 0
                  if data[:stats].key?('players') and data[:stats]['players'].key?(user.kag_user)
                    kills = data[:stats]['players'][user.kag_user].key?('kills') ? data[:stats]['players'][user.kag_user]['kills'] : data[:stats]['players'][user.kag_user]['kill']
                    deaths = data[:stats]['players'][user.kag_user].key?('deaths') ? data[:stats]['players'][user.kag_user]['deaths'] : data[:stats]['players'][user.kag_user]['death']
                  end

                  players[user.name] = {
                    :class => cls,
                    :kills => kills.to_i,
                    :deaths => deaths.to_i,
                  }
                end
                data[:teams][team.name.to_s] = players
              end

            end
            if match.server
              data[:server_name] = match.server.name
            end

            self.success('',data)
          else
            self.failure('err_nf',id)
          end
        end

        def list
          return self.read(@params[:id]) if @params.key?(:id)

          limit = @params[:limit] || 10
          offset = @params[:offset] || 0
          total = ::Match.select('`matches`.*,`servers`.`name` AS `server_name`').joins(:server).where('matches.end_votes = 0 AND matches.ended_at IS NOT NULL').count
          matches = ::Match.select('`matches`.*,`servers`.`name` AS `server_name`').joins(:server).where('matches.end_votes = 0 AND matches.ended_at IS NOT NULL').limit(limit).offset(offset).order('matches.created_at DESC')
          if matches
            list = []
            matches.each do |match|
              data = SymbolTable.new(match.attributes)
              if match.stats
                stats = SymbolTable.new(JSON.parse(match.stats))
                if stats
                  if stats.key?(:wins)
                    data[:wins] = stats[:wins]
                    data[:winner] = _winner(stats[:wins])
                  end
                  data[:players] = stats.players.keys if stats.key?(:players)
                end
              end
              data.delete(:stats)
              list << data
            end
            self.collection(list,total)
          else
            self.failure('err_nf',matches)
          end
        end

        def _winner(wins)
          wins.each do |team,w|
            if w >= 2
              return team
            end
          end
          false
        end

      end
    end
  end
end