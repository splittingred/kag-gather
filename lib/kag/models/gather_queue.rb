require 'kag/models/model'

class GatherQueue < KAG::Model
  has_many :gather_queue_players

  def players
    self.gather_queue_players
  end

  def is_full?
    self.players.length >= KAG::Config.instance[:match_size]
  end

  def reset
    GatherQueuePlayer.destroy_all(["gather_queue_id = ?",self.id])
  end

  def has?(user)
    !self.players.joins(:user).where(:users => {:authname => user.authname}).first.nil?
  end

  def add(user)
    added = false
    u = User.find_by_authname(user.authname)
    unless u
      u = User.new({
        :authname => authname,
        :nick => user.nick,
        :kag_user => "",
        :ip => user.ip,
        :created_at => Time.now,
      })
      u.save
    end
    player = GatherQueuePlayer.where(:user_id => u.id).first
    if player # already in queue
      false
    else
      gp = GatherQueuePlayer.new({
        :gather_queue_id => self.id,
        :user_id => u.id,
        :created_at => Time.now
      })
      added = gp.save
    end
    added
  end

  def remove(user)
    removed = false
    queue_player = self.players.joins(:user).where(:users => {:authname => user.authname}).first
    if queue_player and
      queue_player.destroy
      removed = true
    end
    removed
  end

  def list
    m = []
    self.players.joins(:user).each do |player|
      m << player.user.nick
    end
    m.join(", ")
  end
end