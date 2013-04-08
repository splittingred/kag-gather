require 'kag/models/model'

class Substitution < KAG::Model
  belongs_to :match
  belongs_to :team
  belongs_to :old_player, :class_name => "Player", :foreign_key => "old_player_id"
  belongs_to :new_player, :class_name => "Player", :foreign_key => "new_player_id"

  attr_accessor :gather

  class << self
    ##
    # Request a sub for a match
    #
    # @param [Match] match
    # @param [Player] player
    # @return [Boolean]
    #
    def request(match,player)
      team = match.get_team_for(player.user)
      return false unless team

      sub = Substitution.new
      sub.old_player_id = player.id
      sub.match_id = match.id
      sub.team_id = team.id
      sub.status = "open"
      saved = sub.save
      if saved
        player.user.inc_stat(:desertions)
        player.deserted = true
        player.save
        sub
      else
        false
      end
    end

    def find_for(match)
      Substitution.where(:match_id => match.id,:status => "open").first
    end
  end

  ##
  # Take a substitution and assign it to a user
  #
  # @param [User] user
  # @return [Boolean]
  #
  def take(user)
    unless user.class == User
      user = User.fetch(user)
      return false unless user.class == User
    end

    player = Player.new
    player.user_id = user.id
    player.match_id = self.match.id
    player.team_id = self.team.id
    player.is_sub = true
    if player.save
      self.new_player_id = player.id
      self.status = "taken"
      saved = self.save
      if saved
        user.inc_stat(:substitutions)
        if self.old_player and self.old_player.user
          self.old_player.user.inc_stat(:substituted)
        end
        true
      else
        false
      end
    else
      false
    end
  end
end
