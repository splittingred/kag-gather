require 'api/controllers/base'
module KAG
  module API
    module Controller
      class Achievement < Base
        @class_key = 'Achievement'
        @primary_key = :name

        def get
          if @params[:id]
            self.read(@params[:id])
          elsif @params[:code]
            @primary_key = :code
            self.read(@params[:code])
          else
            self.list
          end
        end

        def read(id)
          if @primary_key == :code
            ach = ::Achievement.where('code = ?',@params[:code]).first
          else
            ach = ::Achievement.where(:id => id).first
          end
          if ach

            limit = (@params[:limit] || 20).to_i
            offset = (@params[:offset] || 0).to_i

            d = SymbolTable.new(ach.attributes)
            d[:users] = ach.users_as_list(limit,offset)
            d[:users_close] = ach.users_close(limit,offset)

            d[:related] = ach.related

            d[:trajectory] = ach.trajectory

            self.success('',d)
          else
            self.failure('err_nf')
          end
        end

        def list
          limit = @params[:limit] || 25
          start = @params[:start] || 0

          total = ::Achievement.count
          achievements = ::Achievement.select('`achievements`.*, (SELECT COUNT(*) FROM `user_achievements` WHERE `achievement_id` = `achievements`.`id`) AS `users`').order('stat ASC, value ASC').offset(start).limit(limit)
          if achievements
            list = []
            achievements.each do |achievement|
              data = SymbolTable.new(achievement.attributes)
              list << data
            end
            self.collection(list,total)
          else
            self.failure('err_nf',c)
          end
        end

      end
    end
  end
end