require 'kag/models/model'

class Clan < KAG::Model
  has_many :users

  class << self

    def fetch(name)
      clan = ::Clan.find_by_name(name)
      unless clan
        clan = ::Clan.new
        clan.name = name
        unless clan.save
          clan = nil
        end
      end
      clan
    end
  end

  def add_member(user)
    user = User.fetch(user) unless user.class == User
    unless user.clan_id == self.id
      user.clan_id = self.id
      user.save
    end
  end
end
