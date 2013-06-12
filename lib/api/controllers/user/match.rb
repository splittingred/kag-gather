require 'api/controllers/base'
module KAG
  module API
    module Controller
      class UserMatch < Base
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
            limit = @params[:limit] || 20
            offset = @params[:offset] || 0
            total = user.matches.count
            list = user.recent_matches(limit,offset)
            self.collection(list,total,{
                :all_total => ::Match.where('end_votes = 0').count
            })
          else
            self.failure('err_nf',c)
          end
        end

      end
    end
  end
end