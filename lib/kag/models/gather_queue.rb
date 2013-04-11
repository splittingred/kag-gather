require 'kag/models/model'

class GatherQueue < KAG::Model
  has_many :gather_queue_players
  has_many :users, :through => :gather_queue_players

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

  def add(user,silent = false)
    if self.has_player?(user)
      "#{user.authname} is already in the queue!"
    else
      match = Match.player_in(user)
      if match
        "#{user.authname} is already in a match!"
      else
        player = GatherQueuePlayer.where(:user_id => user.id).first
        if player # already in queue
          "#{user.authname} is already in the queue!"
        else
          gp = GatherQueuePlayer.new({
            :gather_queue_id => self.id,
            :user_id => user.id,
            :created_at => Time.now
          })
          added = gp.save
          if added
            KAG.gather.send_channels_msg "Added #{user.authname} to queue (#{::Match.type_as_string}) [#{self.length}]" unless silent
            user.inc_stat(:adds)
            KAG::Stats::Main.add_stat(:adds)
            check_for_new_match
            true
          else
            "Failed to add to queue!"
          end
        end
      end
    end
  end

  def check_for_new_match
    if self.is_full?
      unless self.start_match
        KAG.gather.send_channels_msg "Could not find any available servers!"
        debug "FAILED TO FIND UNUSED SERVER"
      end
    end
  end

  def remove(user,silent = false)
    removed = false
    user = SymbolTable.new({:authname => user}) if user.class == String
    queue_player = self.player(user)
    if queue_player
      queue_player.destroy
      KAG.gather.send_channels_msg "Removed #{user.authname} from queue (#{::Match.type_as_string}) [#{self.length}]" unless silent
      removed = true
    else
      puts "User #{user.authname} is not in the queue!"
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
  def start_match
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
    match.setup_teams(players)
    match.notify_players_of_match_start
    match.start
    true
  end
end