require 'kag/models/model'

class Achievement < KAG::Model
  has_many :user_achievements
  has_one :next_achievement, :foreign_key => 'prior', :class_name => 'Achievement'

  class << self

    def recalculate(users)
      granted = SymbolTable.new
      users.each do |user|
        granted[user.name.to_sym] = [] unless granted[user.name.to_sym]

        stats = user.stats_as_hash
        achievements = user.achievements_as_list

        ::Achievement.all.each do |ach|
          if stats.key?(ach.stat) and !achievements.include?(ach.code.to_s)
            value = ach.value.to_i
            op = ach.operator.to_sym
            if stats[ach.stat].send(op,value)
              ach.grant(user)
              granted[user.name.to_sym] << ach.code
            end
          end
        end
      end
      granted
    end

    def grant(achievement,user)
      achievement = Achievement.find_by_code(achievement,user)
      if achievement
        achievement.grant(user)
      end
    end

    def recent(limit = 20)
      Achievement.select('achievements.*,users.kag_user,user_achievements.created_at').joins('JOIN user_achievements ON achievements.id = user_achievements.achievement_id JOIN users ON users.id = user_achievements.user_id').order('user_achievements.created_at DESC, achievements.stat ASC, achievements.value ASC').limit(limit)
    end
  end

  def grant(user)
    return false unless ::UserAchievement.where(:user_id => user.id,:achievement_id => self.id).count == 0

    puts "Granting #{self.code} to #{user.name}"
    ua = ::UserAchievement.new
    ua.user_id = user.id
    ua.achievement_id = self.id
    ua.save
  end

  def users
    User.joins(:user_achievements).select('users.*,user_stats.value').joins('INNER JOIN user_stats ON users.id = user_stats.user_id AND user_stats.name = "'+self.stat+'"').where(:user_achievements => {:achievement_id => self.id}).order('value DESC')
  end

  def users_close(range = 0.75)
    list = SymbolTable.new
    op = self.operator.to_sym
    value = self.value.to_i
    proximity = value * range
    UserStat.select('user_stats.*,users.kag_user').joins(:user).where(:name => self.stat).order('user_stats.value DESC').each do |stat|
      if stat.value.to_i.send(op,proximity) and stat.value < value
        list[stat.kag_user] = stat.value
      end
    end
    list
  end

  def users_as_list
    l = {}
    self.users.select('users.*,user_stats.value').joins('INNER JOIN user_stats ON users.id = user_stats.user_id AND user_stats.name = "'+self.stat+'"').order('value DESC').each do |u|
      l[u.name] = u.value
    end
    l
  end

  def prior_achievement
    Achievement.where(:id => self.prior).first
  end

  def trajectory(list = [])
    current = self
    until (prior = current.prior_achievement).nil?
      list << prior.attributes
      current = prior
    end
    list << self.attributes.merge({:current => true})
    current = self
    until (na = current.next_achievement).nil?
      list << na.attributes
      current = na
    end
    list
  end
end
