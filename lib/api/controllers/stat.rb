require 'api/controllers/base'
module KAG
  module API
    module Controller
      class Stat < Base
        @class_key = 'UserStat'
        @primary_key = :name

        def get
          name = @params[:name].to_s || ''
          if name.empty?
            self.failure('err_ns')
          else
            limit = @params[:limit] || 20
            times = ::UserStat.where(:name => name).sum('value')
            users_count = ::UserStat.select('*,users.kag_user').joins(:user).where(:user_stats => {:name => name}).count
            users = ::UserStat.select('*,users.kag_user').joins(:user).where(:user_stats => {:name => name}).limit(limit).order('value DESC')
            list = []
            users.each do |u|
              list << {
                  :user => u.kag_user,
                  :times => u.value
              }
            end
            self.collection(list,users_count,{
                :name => name,
                :times => times,
            })
          end
        end
      end
    end
  end
end