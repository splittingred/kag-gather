require 'kag/models/model'

class Player < KAG::Model
  belongs_to :match
  belongs_to :team
  belongs_to :user

  class << self
    def fetch_by_kag_user(kag_user)
      Player.select("*").joins(:user).where(:users => {:kag_user => kag_user.to_s}).first
    end
  end
end