require 'api/controllers/base'
module KAG
  module API
    module Controller
      class Wins < GetOnly
        def get
          users = ::User.select("users.*,user_stats.value AS value").joins(:user_stats).where(:user_stats => {:name => "wins"}).order("user_stats.value DESC")
          list = []
          users.each do |u|
            list << {:user => u.name,:wins => u.value}
          end
          self.collection(list,10)
        end
      end
    end
  end
end