require 'kag/models/model'

class Player < KAG::Model
  belongs_to :match
  belongs_to :team
  belongs_to :user
end