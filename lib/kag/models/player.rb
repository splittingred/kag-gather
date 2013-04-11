require 'kag/models/model'

class Player < KAG::Model
  belongs_to :match
  belongs_to :team
  belongs_to :user

  class << self
    def fetch_by_kag_user(kag_user)
      Player.select("*").joins(:user).where(:users => {:kag_user => kag_user.to_s}).first
    end

    def is_playing?(user)
      authname = user.class == String ? user : user.authname

      !Player.select("*").joins(:match).joins(:user).where(:matches => {:ended_at => nil},:users => {:authname => authname}).first.nil?
    end
  end
end