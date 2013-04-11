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
            data[:players] = []
            match.users.each do |u|
              data[:players] << u.name
            end

            self.success('',data)
          else
            self.failure('err_nf',id)
          end
        end
      end
    end
  end
end