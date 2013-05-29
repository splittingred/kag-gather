require 'kag/models/model'

class Substitution < KAG::Model
  belongs_to :match
  belongs_to :team
  belongs_to :old_player, :class_name => "Player", :foreign_key => "old_player_id"
  belongs_to :new_player, :class_name => "Player", :foreign_key => "new_player_id"

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

      return false if Substitution.exists(match,player)

      sub = Substitution.new
      sub.old_player_id = player.id
      sub.match_id = match.id
      sub.team_id = team.id
      sub.status = 'open'
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
      Substitution.where(:match_id => match.id,:status => 'open').first
    end

    def exists(match,player)
      Substitution.where(:match_id => match.id,:status => 'open',:old_player_id => player.id).first
    end

    def list_open
      Substitution
        .select('substitutions.*')
        .select('matches.num_players')
        .select('users.kag_user')
        .select('servers.name')
        .select('teams.name')
        .select('players.cls')
        .joins(:match)
        .joins('INNER JOIN servers ON servers.id = matches.server_id')
        .joins('INNER JOIN players ON players.id = substitutions.old_player_id')
        .joins('INNER JOIN users ON users.id = players.user_id')
        .joins('INNER JOIN teams ON teams.id = players.team_id')
        .where('substitutions.status = ? AND matches.ended_at IS NULL','open')
    end

    def list_open_text
      subs = ::Substitution.list_open
      l = []
      subs.each do |s|
        l << "Match #{s.match_id}, #{s.name}, for user #{s.kag_user}. Type !sub #{s.match_id} to join."
      end
      l.length > 0 ? l.join(' - ') : 'No open sub spots available at this time.'
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
      self.status = 'taken'
      old_user = (self.old_player and self.old_player.user) ? self.old_player.user : nil
      done = self.save
      if done
        user.inc_stat(:substitutions)
        if old_user
          old_user.inc_stat(:substituted)
        end

        q = ::GatherQueue.first
        if q and q.has_player?(user)
          q.remove(user)
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
