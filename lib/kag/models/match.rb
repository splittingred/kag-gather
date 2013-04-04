require 'kag/models/model'
require 'kag/config'
require 'kag/stats/main'

class Match < KAG::Model
  belongs_to :server
  has_many :teams
  has_many :players
  has_many :users, :through => :players

  attr_accessor :gather

  def self.total_in_progress
    Match.count(:conditions => {:ended_at => nil})
  end

  def self.active
    Match.all(:conditions => {:ended_at => nil})
  end

  def self.player_in(user)
    m = false
    Match.active.each do |match|
      if match.has_player?(user)
        m = match
      end
    end
    m
  end

  def self.type_as_string
    ms = KAG::Config.instance[:match_size].to_i
    ts = (ms / 2).ceil
    "#{ts.to_s}v#{ts.to_s} #{KAG::Config.instance[:match_type]}"
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
      if self.gather
        self.gather.matches.delete(self.server.name)
        msg = "Match #{self[:id]} at #{self.server.name} finished!"
        self.gather.send_channels_msg(msg)
      end
    end
    data
  end

  def has_player?(user)
    self.users(true).where(:authname => user.authname)
  end

  def setup_teams(queue_players)
    queue_players.shuffle!

    match_size = KAG::Config.instance[:match_size].to_i
    match_size = 2 if match_size < 2

    team_list = [{
      :color => "\x0312",
      :name => "Blue Team"
    },{
       :color => "\x0304",
       :name => "Red Team"
    }]
    players_per_team = (match_size / 2).floor.to_i

    puts "MATCH SIZE #{match_size.to_s}"
    puts "Players Per Team: #{players_per_team.to_s}"

    lb = 0
    team_list.each do |ts|
      eb = lb+players_per_team-1
      eb = queue_players.length if eb > queue_players.length-1
      x = 0
      ps = []
      queue_players.each do |qp|
        if x >= lb and x <= eb
          ps << Player.new({
            :user_id => qp.user_id,
            :match => self
          })
        end
        x = x + 1
      end
      lb = players_per_team

      self.teams << Team.new({
        :num_players => ps.length,
        :players => ps,
        :name => ts[:name],
        :color => ts[:color],
      })
    end
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


  # TODO redo all sub stuff to use new table
  def needs_sub?
    self.subs_needed > 0
  end

  def sub_in(user)
    placement = false
    if needs_sub?
      KAG::User::User.add_stat(user,:substitutions)
      KAG::Stats::Main.add_stat(:substitutions_done)

      if self.gather
        self.gather.send_channel_msg "#{user.nick} is now subbing in at #{self.server.name}. Subs still needed: #{self.subs_needed.to_s}"
        user.send "Please #{self.server.text_join}"
      end
    end
    placement
  end

  def kick_all
    self.server.kick_all
  end
end