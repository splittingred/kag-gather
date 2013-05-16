require 'kag/models/model'

class UserAchievement < KAG::Model
  belongs_to :achievements
  belongs_to :users

  class << self

  end
end
