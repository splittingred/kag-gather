require 'kag/models/model'

class GatherQueue < KAG::Model
  has_many :gather_queue_players
  has_many :users, :through => :gather_queue_players

  attr_accessor :gather

  def players(bust_cache = false)
    self.gather_queue_players(bust_cache)
  end

  def is_full?
    self.players(true).length >= KAG::Config.instance[:match_size]
  end

  def reset
    GatherQueuePlayer.destroy_all(["gather_queue_id = ?",self.id])
  end

  def player(user)
    self.players(true).joins(:user).where(:users => {:authname => user.authname}).first
  end

  def has_player?(user)
    !self.player(user).nil?
  end

  def add(user)
    added = false
    u = User.find_by_authname(user.authname)
    unless u
      u = User.new({
        :authname => user.authname,
        :nick => user.nick,
        :kag_user => "",
        :host => user.host,
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

  def remove(user,send_msg = true)
    removed = false
    queue_player = self.player(user)
    if queue_player
      queue_player.destroy
      self.gather.send_channels_msg "Removed #{user.authname} from queue (#{::Match.type_as_string}) [#{self.length}]" if self.gather
      removed = true
    else
      puts "Could not find #{user.authname} to remove from queue"
    end
    removed
  end

  def list
    m = []
    self.users(true).each do |user|
      m << user.nick
    end
    m.join(", ")
  end

  def list_text
    "Queue (#{::Match.type_as_string}) [#{self.players.length}] #{self.list}"
  end

  def length
    self.players(true).length
  end

  ##
  # Start the match from the queue and reset it
  #
  def start_match(gather)
    server = ::Server.find_unused
    unless server
      return false
    end
    players = self.players(true)

    # reset queue first to prevent 11-player load
    self.reset

    match = ::Match.new({
       :server => server,
    })
    match.gather = gather
    match.setup_teams(players)
    match.notify_players_of_match_start
    match.start(gather)
    true
  end
end