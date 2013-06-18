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
      Match.joins('INNER JOIN players ON players.match_id = matches.id')
        .joins("INNER JOIN users ON users.id = players.user_id AND users.kag_user = '#{user.kag_user}'")
        .where('matches.ended_at IS NULL').first
    end

    def type_as_string
      ms = KAG::Config.instance[:match_size].to_i
      ts = (ms / 2).ceil
      "#{ts.to_s}v#{ts.to_s} #{KAG::Config.instance[:match_type]}"
    end
    def list_open
      Match.select('matches.*,servers.name AS server_name').joins(:server).where('matches.ended_at IS NULL')
    end
    def list_open_text
      l = []
      Match.list_open.each do |m|
        l << "##{m.id}: #{m.server_name}"
      end
      l.length > 0 ? l.length.to_s+' matches in progress: '+l.join(', ') : 'No open matches currently.'
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
      KAG.gather.send_channels_msg("Match #{self.id.to_s} at #{self.server.name} now completed. You may now re-add to the queue. Stats: http://gather.splittingred.com/match/#{self.id.to_s}")
    end
    data
  end

  def has_player?(user)
    self.users(true).where(:kag_user => user.kag_user)
  end

  def setup_teams(queue_players,sort_by_score = true)
    if sort_by_score
      queue_players.sort do |a,b|
        a.user.score <=> b.user.score
      end
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
      puts "Assigning #{qp.user.name}:#{qp.user.score} to #{teams.at(idx)[:name]}"
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
    Player.where(:user_id => user.id,:match_id => self.id,:deserted => false).first
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
          KAG.gather.send_channels_msg("Substitute requested for match #{self.id}, player #{user.name}, #{substitution.team.name}. Type \"!sub #{self.id}\" to join up.") if KAG.gather
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
        u.send('You cannot sub into a match when you\'re already playing in one!') if u.class == ::Cinch::User
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
    stats = self.stats_as_hash
    if stats.key?(:wins)
      stats[:wins].each do |team,wins|
        if wins >= 2
          winner = team
        end
      end
    end
    winner
  end

  def info
    players = Player
      .joins('INNER JOIN users ON users.id = players.user_id')
      .joins('INNER JOIN teams ON teams.id = players.team_id')
      .select('players.*')
      .select('teams.name AS team_name, teams.color AS team_color')
      .select('users.kag_user AS kag_user')
      .where('players.match_id = ? AND players.deserted = ?',self.id,0)
      .order('teams.name ASC, users.kag_user ASC')

    list = []
    players.each do |p|
      list << SymbolTable.new(p.attributes)
    end
    list
  end

  def info_text
    inf = self.ended_at.nil? ? 'IN PROGRESS' : 'Ended at '+self.ended_at.to_s(:long)
    txt = []
    players = self.info
    team_players = []
    if players.first
      ct = players.first.team_name.to_s
      cc = players.first.team_color
      players.each do |p|
        unless ct == p.team_name.to_s
          txt << cc+' '+ct+': '+team_players.join(', ')
          team_players = []
          ct = p.team_name.to_s
          cc = p.team_color
        end
        team_players << p.kag_user
      end
    else
      cc = ''
      ct = ''
    end
    txt << cc+ct+': '+team_players.join(', ')
    self.id.to_s+': '+inf+' - '+self.server.name+': '+txt.join(" \x0303VS ")
  end

end