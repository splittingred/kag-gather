require 'kag/models/model'

class Player < KAG::Model
  belongs_to :match
  belongs_to :team
  belongs_to :user

  class << self
    def fetch_by_kag_user(kag_user)
      Player.select('*').joins(:user).where(:users => {:kag_user => kag_user.to_s}).first
    end

    def is_playing?(user)
      kag_user = user.class == String ? user : user.kag_user

      !Player.select('*').joins(:match).joins(:user).where(:matches => {:ended_at => nil},:users => {:kag_user => kag_user}).first.nil?
    end
  end
end