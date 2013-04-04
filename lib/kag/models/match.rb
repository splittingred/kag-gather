require 'kag/models/model'
require 'kag/config'
require 'kag/stats/main'

class Match < KAG::Model
  belongs_to :server
  has_many :teams
  has_many :players

  attr_accessor :gather

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
            :user_id => qp.user_id
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
end