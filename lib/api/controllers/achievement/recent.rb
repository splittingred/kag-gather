require 'api/controllers/base'
module KAG
  module API
    module Controller
      class AchievementRecent < Base
        @class_key = 'User'
        @primary_key = :kag_user

        def get
          self.list
        end
        def list
          achievements = ::Achievement.recent
          if achievements
            list = []
            achievements.each do |achievement|
              data = SymbolTable.new(achievement.attributes)
              list << data
            end
            self.collection(list,list.count)
          else
            self.failure('err_nf',c)
          end
        end

      end
    end
  end
end