require 'api/controllers/base'
module KAG
  module API
    module Controller
      class UserAchievement < Base
        @class_key = 'Achievement'
        @primary_key = :code

        def get
          if @params[:id]
            self.read(@params[:id])
          elsif @params[:username]
            @primary_key = :username
            self.read(@params[:username])
          else
            self.list
          end
        end
        def read(id)
          if @primary_key == :username
            user = ::User.where('authname = ? OR kag_user = ?',@params[:username],@params[:username]).first
          else
            user = ::User.where(:id => id).first
          end
          if user
            list = []
            limit = @params[:limit] || 100
            offset = @params[:offset] || 0
            total = user.achievements.count
            user.achievements.limit(limit).offset(offset).each do |ach|
              list << {
                  :name => ach.name,
                  :description => ach.description,
                  :code => ach.code
              }
            end
            self.collection(list,total,{
                :all_total => ::Achievement.count
            })
          else
            self.failure('err_nf',c)
          end
        end

      end
    end
  end
end