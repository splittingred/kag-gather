require 'kag/models/model'

class GatherQueue < KAG::Model
  has_many :gather_queue_players

  def players
    self.gather_queue_players
  end
end