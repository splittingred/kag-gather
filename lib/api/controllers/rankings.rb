require 'api/controllers/base'
module KAG
  module API
    module Controller
      class Rankings < GetOnly
        def get
          limit = @params[:limit] || 20
          offset = @params[:offset] || 0
          list = ::User.rank_top(limit,offset,false)
          self.collection(list,20)
        end
      end
    end
  end
end