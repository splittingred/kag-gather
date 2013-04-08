require 'kag/models/model'

class User < KAG::Model
  has_many :players
  has_many :matches, :through => :players
  has_many :gather_queue_players
  has_many :queues, :through => :gather_queue_players
  has_many :user_stats

  class << self
    def create(user)
      u = User.new
      u.authname = user.authname
      u.nick = user.nick
      u.host = user.host
      u.created_at = Time.now
      u.save
    end

    def fetch(user)
      return user if user.class == User
      if user.class == String
        authname = user
      else
        return false unless user.authed?
        authname = user.authname
      end

      u = User.find_by_authname(authname)
      unless u
        u = User.new({
          :authname => user.class == String ? user : user.authname,
          :nick => user.class == String ? user : user.nick,
          :kag_user => "",
          :host => user.class == String ? '' : user.host,
          :created_at => Time.now,
        })
        u.save
      end
    end
  end

  def linked?
    u.kag_user != '' and !u.kag_user.nil?
  end

  def unlink
    u.kag_user = ""
    u.save
  end

  def stats(bust_cache = true)
    self.user_stats(bust_cache)
  end

  def stats_text
    kd_ratio = self.stat("kills").to_s+'/'+self.stat("deaths").to_s
    "#{self.authname} has played in #{self.matches(true).count.to_s} matches, with a K/D ratio of: #{kd_ratio}"
  end

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

  def delete_stat(k)
    s = self.stat(k,false)
    if s
      s.destroy
    end
  end

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

  def ignore(hours,reason = '',creator = nil)
    Ignore.them(self.authname,hours,reason,creator)
  end
end