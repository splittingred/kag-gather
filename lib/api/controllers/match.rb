require 'api/controllers/base'
module KAG
  module API
    module Controller
      class Match < Base
        @@class_key = 'Match'

        def read(id)
          match = ::Match.find(id)
          if match
            data = match.attributes
            if match.stats
              data[:stats] = JSON.parse(match.stats)
              data[:stats].delete(:units_depleted)
            end
            if match.server
              data[:server_name] = match.server.name
            end
            data[:players] = []
            match.users.each do |u|
              data[:players] << u.name
            end

            self.success('',data)
          else
            self.failure('err_nf',id)
          end
        end

        def list
          limit = @params[:limit] || 10
          offset = @params[:offset] || 0
          c = ::Match.select('`matches`.*,`servers`.`name` AS `server_name`').joins(:server).where('matches.end_votes = 0 AND matches.ended_at IS NOT NULL').limit(limit).offset(offset).order('matches.created_at DESC')
          if c
            us = []
            c.each do |u|
              ud = SymbolTable.new(u.attributes)
              ud.delete(:stats)
              us << ud
            end
            self.success('',us)
          else
            self.failure('err_nf',c)
          end
        end

      end
    end
  end
end