require 'kag/models/model'
require 'kag/config'
require 'kag/stats/main'

class Match < KAG::Model
  belongs_to :server
  has_many :teams
  has_many :players
  has_many :users, :through => :players
  has_many :substitutions

  class << self
    def total_in_progress
      Match.count(:conditions => {:ended_at => nil})
    end

    def active
      Match.all(:conditions => {:ended_at => nil})
    end

    def player_in(user)
      m = false
      Match.active.each do |match|
        if match.has_player?(user)
          m = match
        end
      end
      m
    end

    def type_as_string
      ms = KAG::Config.instance[:match_size].to_i
      ts = (ms / 2).ceil
      "#{ts.to_s}v#{ts.to_s} #{KAG::Config.instance[:match_type]}"
    end
  end

  def start
    #self.end_votes = 0 unless self.end_votes
    KAG::Stats::Main.add_stat(:matches_started)
    if self.server
      self.started_at = Time.now()
      if self.save
        begin
          self.server.start(self)
        rescue Exception => e
          puts e.message
          puts e.backtrace.join("\n")
        #ensure
          #self.server.disconnect if self.server
        end
      end
    end
  end

  def cease
    data = SymbolTable.new
    self.ended_at = Time.now
    if self.save
      if self.server
        begin
          data = self.server.stop
        rescue Exception => e
          puts e.message
          puts e.backtrace.join("\n")
        end
      end
      KAG.gather.send_channels_msg("Match #{self.id} at #{self.server.name} now completed. You may now re-add to the queue.")
    end
    data
  end

  def has_player?(user)
    self.users(true).where(:kag_user => user.kag_user)
  end

  def setup_teams(queue_players,shuffle = true)
    queue_players.shuffle! if shuffle

    queue_players.sort_by do |qp|
      qp.user.score
    end

    teams = []
    teams << {
      :color => "\x0312",
      :name => 'Blue Team',
      :players => []
    }
    teams << {
       :color => "\x0304",
       :name => 'Red Team',
       :players => []
    }

    idx = 0
    queue_players.each do |qp|
      teams.at(idx)[:players] << Player.new({
        :user_id => qp.user_id,
        :match => self
      })
      idx += 1
      idx = 0 if idx >= teams.length
    end

    teams.each do |t|
      self.teams << Team.new({
        :num_players => t[:players].length,
        :players => t[:players],
        :name => t[:name],
        :color => t[:color],
      })
    end

    self.num_players = queue_players.length
    self.num_teams = teams.length
    self.save
  end

  def active
    self.ended_at.nil?
  end

  def add_end_vote
    self.end_votes += 1
    self.save
  end

  def voted_to_end?
    evt = KAG::Config.instance[:end_vote_threshold].to_i
    evt = 3 if evt < 1
    self.end_votes >= evt
  end

  def clear_end_votes
    self.end_votes = 0
    self.save
  end

  def get_needed_end_votes_left
    evt = KAG::Config.instance[:end_vote_threshold].to_i
    evt - self.end_votes
  end

  def notify_players_of_match_start
    self.send_channel_start_msg
    self.teams.each do |t|
      t.notify_of_match_start
    end
  end

  def send_channel_start_msg
    msg = "MATCH #{self.id} on Server #{self.server.name}: #{::Match.type_as_string} - "
    self.teams.each do |team|
      msg = msg+" "+team.text_for_match_start
    end
    KAG.gather.send_channels_msg(msg,false)
  end

  def get_team_for(user)
    p = self.get_player_for(user)
    if p
      p.team
    else
      nil
    end
  end

  def get_player_for(user)
    Player.where(:user_id => user.id,:match_id => self.id).first
  end

  def remove_player(user)
    player = get_player_for(user)
    if player
      self.request_sub(user)
    end
  end

  ##
  # Request a sub for the match for a given user
  #
  # @param [String|User] user
  # @return [Boolean|Substitution]
  #
  def request_sub(user)
    requested = false
    user = User.fetch(user)
    if user
      player = self.get_player_for(user)
      if player
        substitution = Substitution.request(self,player)
        if substitution
          KAG.gather.send_channels_msg("Substitute requested for match #{self.id}, team #{substitution.team.name}. Type \"!sub #{self.id}\" to join up.") if KAG.gather
          user.inc_stat(:substitutions_requested)
          requested = substitution
        end
      end
    end
    requested
  end

  ##
  # Sub in a user into the match
  #
  # @param [Cinch::User] u
  # @return [Boolean]
  #
  def sub_in(u)
    subbed = false
    user = User.fetch(u)
    if user
      if Player.is_playing?(user)
        u.send("You cannot sub into a match when you're already playing in one!") if u.class == ::Cinch::User
      else
        substitution = Substitution.find_for(self)
        if substitution
          if substitution.take(user)
            u.send("Please join #{substitution.match.server.text_join} | Team: \x03#{substitution.team.color}#{substitution.team.name}") if u.class == ::Cinch::User
            msg = "#{user.name} has subbed into Match #{substitution.match.id} for the #{substitution.team.name}!"
            KAG.gather.send_channels_msg(msg)

            if substitution and substitution.old_player and substitution.old_player.user
              self.server.sub_in(substitution.old_player.user,user,substitution.team)
            end
            subbed = true
          else
            u.send('Could not sub into match!') if u.class == ::Cinch::User
          end
        end
      end
    end
    subbed
  end

  def teams_text
    ts = []
    self.teams(true).each do |team|
      ts << team.name.to_s+': '+team.player_list
    end
    ts.join(' --- ')
  end

  def kick_all
    self.server.kick_all
  end

  def stats_as_hash
    begin
      SymbolTable.new(JSON.parse(self.stats))
    rescue Exception => e
      SymbolTable.new
    end
  end

  def winner
    winner = 'Neither Team'
    wins = self.stats_as_hash[:wins]
    wins.each do |team,wins|
      if wins >= 2
        winner = team
      end
    end
    winner
  end
end