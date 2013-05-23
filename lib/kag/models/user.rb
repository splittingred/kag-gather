require 'kag/models/model'
require 'kag/models/score/scorer'
require 'open-uri'
##
# Abstraction of a User record
#
class User < KAG::Model
  has_many :players
  has_many :matches, :through => :players
  has_many :gather_queue_players
  has_many :gather_queues, :through => :gather_queue_players
  has_many :user_stats
  has_many :user_achievements
  belongs_to :clan

  class << self
    ##
    # Create a new User record from a Cinch::User
    #
    # @param [Cinch::User] user
    # @return [Boolean|User]
    #
    def create(user)
      u = User.new
      u.authname = user.authname
      u.nick = user.nick
      u.host = user.host
      u.created_at = Time.now
      if u.save
        u
      else
        false
      end
    end

    ##
    # Fetch the User object for a authname or user
    #
    # @param [String|Symbol|Cinch::User]
    # @return [User|Boolean]
    #
    def fetch(user)
      return user if user.class == User
      if user.class == String
        authname = user
      else
        if user.authed?
          authname = user.authname
        else
          host = (user.respond_to?(:host_unsynced) ? user.host_unsynced : user.host)
          u = User.find_login_by_host(host)
          return false unless u
          authname = u.authname
        end
      end

      u = User.find_by_authname(authname)
      if !u and user.class == String
        u = User.find_by_kag_user(authname)
      end
      u
    end

    def login(m)
      m.user.send "Please go to http://stats.gather.kag2d.nl/sso/?t=#{URI::encode(m.user.host)} to link login to your main KAG Account. This will redirect you to a secure, official KAG-sponsored SSO site that keeps your information secure and only on the kag2d.com servers."
    end

    def clear_expired_logins
      User.where('temp_end_at <= ? AND temp = ?',Time.now,true).each do |u|
        u.logout
      end
    end

    def find_login_by_host(host)
      User.where(:host => host,:temp => true).first
    end

    def score(user)
      User.find_by_kag_user(user).do_score
    end

    def rank_top(num,return_string = true)
      users = User.select('GROUP_CONCAT(`kag_user`) AS `kag_user`, `score`').where('score > 0').group('score').order('score DESC').limit(num)
      list = []
      idx = 1
      users.each do |u|
        name = u.kag_user.split(',').join(', ')
        if return_string
          list << "##{idx}: #{name} - #{u.score.to_s}"
        else
          list << {:name => name,:score => u.score}
        end
        idx += 1
      end
      return_string ? "TOP 10: #{list.join(' | ')}" : list
    end

    def rescore_all
      User.order('score DESC').each {|u| u.do_score}
    end

    def clear_duplicates(username)
      return false if User.where(:kag_user => username.to_s).count < 2

      old = []
      to_merge = nil
      User.where(:kag_user => username.to_s).each do |user|
        if user.authname.to_s.empty?
          old << user
        else
          to_merge = user
        end
      end
      to_merge = old.shift if to_merge.nil?
      return false unless to_merge

      old.each do |o|
        to_merge.merge_from(o)
      end

      to_merge
    end
  end

  def name
    self.kag_user.empty? ? self.authname : self.kag_user
  end

  ##
  # See if the user is linked
  #
  # @return [Boolean]
  #
  def linked?
    !self.kag_user.nil? and !self.kag_user.to_s.empty?
  end

  ##
  # Unlink the user from their KAG account
  #
  # @return [Boolean]
  #
  def unlink
    self.kag_user = ''
    self.save
  end

  ##
  # Get the stats for the user
  #
  # @param [Boolean] bust_cache
  # @return [Array]
  #
  def stats(bust_cache = true)
    UserStat.select('*,(SELECT (COUNT(*)+1) FROM `user_stats` AS `us2` WHERE `us2`.`name` = `user_stats`.`name` AND `us2`.`user_id` != '+self.id.to_s+' AND `us2`.`value` > `user_stats`.`value` ) AS `rank`').where('user_id = ?',self.id)
  end

  def stats_as_hash
    h = SymbolTable.new
    self.stats(true).each do |s|
      h[s.name.to_sym] = s.value.to_i
    end
    h
  end

  def achievements
    Achievement.joins(:user_achievements).where(:user_achievements => {:user_id => self.id}).order('stat ASC, value ASC')
  end

  def achievements_as_list
    l = []
    self.achievements.each do |a|
      l << a.code
    end
    l
  end

  def achievements_close(range = 0.75)
    list = SymbolTable.new
    Achievement.select('achievements.*,user_stats.value AS current').joins('JOIN user_stats ON achievements.stat = user_stats.name').where(:user_stats => {:user_id => self.id}).order('achievements.stat ASC, achievements.value ASC').each do |ach|
      op = ach.operator.to_sym
      target = ach.value.to_i
      proximity = target * range
      current = ach.current.to_i
      if current.send(op,proximity) and current < target
        list[ach.code] = {
            :name => ach.name,
            :description => ach.description,
            :target => target,
            :current => current
        }
      end
    end
    list
  end

  def recent_matches(limit = 10,offset = 0)
    list = []
    Match.select('matches.*,teams.name AS team_name,players.cls,players.is_sub,players.deserted')
             .joins('INNER JOIN players ON players.user_id = '+self.id.to_s+' AND matches.id = players.match_id')
             .joins('INNER JOIN teams ON players.team_id = teams.id')
             .where('end_votes = 0 AND ended_at IS NOT NULL')
             .limit(limit).offset(offset).order('ended_at DESC').each do |m|
      d = m.attributes
      d[:winning_team] = m.winner
      d[:won] = d[:winning_team].to_s == m.team_name.to_s
      d[:cls] = m.cls.to_s.capitalize
      stats = m.stats_as_hash
      if stats and stats.key?(:players) and stats[:players].key?(self.kag_user)
        ps = stats[:players][self.kag_user]
        d[:kills] = ps.key?(:kill) ? ps[:kill] : ps[:kills]
        d[:deaths] = ps.key?(:death) ? ps[:death] : ps[:deaths]
        d[:killstreaks] = ps.key?(:killstreaks) ? ps[:killstreaks] : 0
        d[:deathstreaks] = ps.key?(:deathstreaks) ? ps[:deathstreaks] : 0
      end
      list << d
    end
    list
  end

  ##
  # Get the stats text for the user
  #
  # @return [String]
  #
  def stats_text
    wl_ratio = self.stat('wins').to_s+'/'+self.stat('losses').to_s

    t = []
    self.stats(true).each do |stat|
      t << "#{stat.name} #{stat.value}"
    end

    "#{self.authname} has played in #{self.matches(true).count.to_s} matches, with a W/L ratio of: #{wl_ratio}. Other stats: #{t.join(', ')}"
  end

  ##
  # Get a stat value for a user
  #
  # @param [String|Symbol] k
  # @param [Boolean] return_value
  # @return [Integer|Float|UserStat]
  #
  def stat(k,return_value = true)
    s = self.stats.where(:name => k.to_s).first
    if return_value
      if s
        s.value
      else
        0
      end
    else
      s
    end
  end

  ##
  # Set the stat for the user for a key
  #
  # @param [String|Symbol] k
  # @param [Integer|Float|String] v
  # @return [Boolean]
  #
  def set_stat(k,v)
    s = self.stat(k,false)
    unless s
      s = UserStat.new({
        :user => self,
        :name => k.to_s,
        :value => 0,
      })
    end
    s.value = v
    s.save
  end

  ##
  # Delete the stat record for a key
  #
  # @param [String|Symbol] k
  # @return [Boolean]
  #
  def delete_stat(k)
    s = self.stat(k,false)
    if s
      s.destroy
    end
  end

  ##
  # Increase a stat value
  #
  # @param [String|Symbol] key
  # @param [Integer] increment
  # @return [Boolean]
  #
  def inc_stat(k,increment = 1)
    s = self.stat(k,false)
    unless s
      s = UserStat.new({
        :user => self,
        :name => k.to_s,
        :value => 0,
      })
    end
    s.value = s.value.to_i+increment.to_i
    s.save
  end

  ##
  # Decrease a stat value
  #
  # @param [String|Symbol] key
  # @param [Integer] decrement
  # @return [Boolean]
  #
  def dec_stat(k,decrement = 1)
    s = self.stat(k,false)
    unless s
      s = UserStat.new({
        :user => self,
        :name => k.to_s,
        :value => 0,
      })
    end
    s.value = s.value.to_i-decrement.to_i
    s.save
  end

  def kills(victim)
    kills = Kill.where(:killer_id => self.id,:victim_id => victim.id).first
    unless kills
      kills = Kill.new
      kills.killer_id = self.id
      kills.victim_id = victim.id
    end
    kills
  end

  def add_kill(victim,times = 1)
    unless victim.class == User
      victim = User.find_by_kag_user(victim)
    end
    return false if victim.class != User

    kills = self.kills(victim)
    kills.times = kills.times.to_i + times
    kills.streak = kills.streak.to_i + times
    kills.save

    victim_kills = victim.kills(self)
    victim_kills.streak = 0
    victim_kills.save

    if kills.streak >= 10
      Achievement.grant('dominate-10',self)
      Achievement.grant('dominated-10',victim)
    end
    if kills.streak >= 25
      Achievement.grant('dominate-25',self)
      Achievement.grant('dominated-25',victim)
    end
    if kills.streak >= 50
      Achievement.grant('dominate-50',self)
      Achievement.grant('dominated-50',victim)
    end

    kills
  end

  ##
  # Ignore this user
  #
  # @param [Integer] hours
  # @param [String] reason
  # @param [User|String|Cinch::User] creator
  # @return [Boolean]
  #
  def ignore(hours,reason = '',creator = nil)
    Ignore.them(self.authname,hours,reason,creator)
  end

  ##
  # See if this user is ignored
  #
  # @return [Boolean]
  #
  def ignored?
    Ignore.is_ignored?(self.authname)
  end

  def authed?
    !self.authname.to_s.empty?
  end

  def logout
    self.gather_queues.each do |q|
      q.remove(self)
    end

    self.nick = ''
    self.host = ''
    self.temp = 0
    self.temp_end_at = nil
    self.save
  end

  def synchronize(user)
    self.nick = user.nick
    self.host = user.host
    self.save
  end

  def do_score
    KAG::Scorer.score(self)
  end

  def rank
    User.select('DISTINCT `score`').where("kag_user != '' AND score > ?",self.score).order('score DESC').count + 1
  end

  def merge_from(user)
    # if merging this into user
    if self.authname.to_s.empty?
      new_user = user
      old_user = self
    else # otherwise merge user into this
      new_user = self
      old_user = user
    end

    UserStat.where(:user_id => old_user.id).each do |old_us|
      us = UserStat.where(:user_id => new_user.id,:name => old_us.name).first
      unless us
        us = UserStat.new
        us.user_id = new_user.id
        us.name = old_us.name
        us.value = 0
      end
      us.value = us.value.to_i + old_us.value.to_i
      us.save
      old_us.destroy
    end

    old_user.destroy

    new_user.do_score
  end
end