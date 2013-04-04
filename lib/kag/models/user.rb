require 'kag/models/model'

class User < KAG::Model
  has_many :players
  has_many :matches, :through => :players
  has_many :gather_queue_players
  has_many :queues, :through => :gather_queue_players

  def stats
    "#{self.authname} has played in #{self.matches(true).count.to_s} matches."
  end
end