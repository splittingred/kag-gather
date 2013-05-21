require 'api/controllers/base'
module KAG
  module API
    module Controller
      class Achievers < Base
        @class_key = 'User'
        @primary_key = :kag_user

        def get
          self.list
        end
        def list
          achievements = ::UserAchievement.select('COUNT(*) AS `achievements`, `users`.`kag_user`').joins('JOIN users ON users.id = user_achievements.user_id').where('users.kag_user != ""').group('user_achievements.user_id').order('achievements DESC').limit(25)
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