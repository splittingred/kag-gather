require 'kag/models/model'

class User < KAG::Model
  has_many :players
end