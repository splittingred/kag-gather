require 'api/controllers/base'
module KAG
  module API
    module Controller
      class Rankings < GetOnly
        def get
          list = ::User.rank_top(20,false)
          self.collection(list,20)
        end
      end
    end
  end
end