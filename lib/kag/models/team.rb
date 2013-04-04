require 'kag/models/model'

class Team < KAG::Model
  has_many :players
end