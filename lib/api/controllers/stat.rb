require 'api/controllers/base'
module KAG
  module API
    module Controller
      class Stat < Base
        @@class_key = 'UserStat'
        @@primary_key = :name

        def read(name)
          limit = @params[:limit] || 20
          times = ::UserStat.where(:name => name).sum('value')
          users_count = ::UserStat.select('*,users.kag_user').joins(:user).where(:name => name).count
          users = ::UserStat.select('*,users.kag_user').joins(:user).where(:name => name).limit(limit).order('value DESC')
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

        def list
          self.failure('err_nf')
        end

      end
    end
  end
end