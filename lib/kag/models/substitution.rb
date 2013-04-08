require 'kag/models/model'

class Substitution < KAG::Model
  belongs_to :match
  belongs_to :team


end
