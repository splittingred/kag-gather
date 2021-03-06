require 'kag/models/model'

class Team < KAG::Model
  has_many :players
  has_many :users, :through => :players
  has_many :substitutions
  belongs_to :match

  def notify_of_match_start
    #puts "start of team.notify_of_match_start"
    server = self.match.server
    if server
      msg = "Join \x0305#{server.name} - #{server.ip}:#{server.port} \x0306password #{server.password}\x0301 | Visit kag://#{server.ip}/#{server.password} | "
      msg = msg + " \x0303Class: " if KAG::Config.instance[:pick_classes]

      #puts "after message compile in team.notify_of_match_start"

      pl = self.player_list

      self.users(true).each do |user|
        player_msg = msg.clone
        #player_msg = player_msg+cls if KAG::Config.instance[:pick_classes] and cls and !cls.empty?
        player_msg = player_msg+" #{self.color}#{self.name} with: #{pl}"
        irc_user = KAG.gather.bot.user_list.find_ensured(user.nick)
        if irc_user
          irc_user.send(player_msg)
          sleep(2) # prevent excess flood stuff
        else
          puts "Could not find player #{user.authname} to send private message"
        end
      end
    else
      puts 'Could not find server!'
    end
  end

  def text_for_match_start
    "#{self.color}#{self.player_list} (#{self.name})"
  end

  def has_player?(name)
    ct = ::Player
      .select('players.*,users.kag_user')
      .joins('JOIN users ON users.id = players.user_id')
      .where('players.deserted = ? AND players.match_id = ? AND players.team_id = ? AND users.kag_user = ?',0,self.match.id,self.id,name).count
    ct > 0
  end

  def player_list
    ps = []
    self.users(true).where(:players => {:deserted => 0}).each do |user|
      ps << user.name
    end
    ps.join(', ')
  end
end