require 'kag/models/model'

class Achievement < KAG::Model
  has_many :user_achievements
  has_one :next_achievement, :foreign_key => 'prior', :class_name => 'Achievement'

  class << self

    def recalculate(users,match_id = nil)
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
              ach.grant(user,match_id)
              granted[user.name.to_sym] << ach.code
            end
          end
        end
      end
      granted
    end

    def grant(achievement,user,match_id = nil)
      achievement = Achievement.find_by_code(achievement,user)
      if achievement
        achievement.grant(user,match_id)
      end
    end

    def recent(limit = 20)
      Achievement.select('achievements.*,users.kag_user,user_achievements.created_at').joins('JOIN user_achievements ON achievements.id = user_achievements.achievement_id JOIN users ON users.id = user_achievements.user_id').order('user_achievements.created_at DESC, achievements.stat ASC, achievements.value ASC').limit(limit)
    end
  end

  def grant(user,match_id = nil)
    return false unless ::UserAchievement.where(:user_id => user.id,:achievement_id => self.id).count == 0

    puts "Granting #{self.code} to #{user.name}"
    ua = ::UserAchievement.new
    ua.user_id = user.id
    ua.achievement_id = self.id
    ua.match_id = match_id unless match_id.nil?
    ua.save
  end

  def users
    User.joins(:user_achievements).select('users.*,user_stats.value').joins('INNER JOIN user_stats ON users.id = user_stats.user_id AND user_stats.name = "'+self.stat+'"').where(:user_achievements => {:achievement_id => self.id}).order('value DESC')
  end

  def users_close(limit = 20,offset = 0,range = 0.75)
    list = SymbolTable.new
    op = self.operator.to_sym
    value = self.value.to_i
    proximity = value * range
    UserStat.select('user_stats.*,users.kag_user').joins(:user).where(:name => self.stat).order('user_stats.value DESC').limit(limit).offset(offset).each do |stat|
      if stat.value.to_i.send(op,proximity) and stat.value < value
        list[stat.kag_user] = stat.value
      end
    end
    list
  end

  def users_as_list(limit = 20,offset = 0)
    l = {}
    l[:total] = self.users.joins('INNER JOIN user_stats ON users.id = user_stats.user_id AND user_stats.name = "'+self.stat+'"').count
    l[:results] = {}
    l[:offset] = offset

    self.users.select('users.*,user_stats.value')
      .joins('INNER JOIN user_stats ON users.id = user_stats.user_id AND user_stats.name = "'+self.stat+'"')
      .limit(limit).offset(offset)
      .order('user_stats.value DESC').each do |u|
      l[:results][u.kag_user] = u.value
    end
    l
  end

  def related(limit = 10,offset = 0)
    tag = self.code.split('.').first.split('-').first
    list = []
    Achievement.where('code LIKE "%'+tag+'%" AND id != ?',self.id).order('stat ASC, value ASC').limit(limit).offset(offset).each do |a|
      list << {
        :code => a.code,
        :name => a.name,
        :description => a.description
      }
    end
    list
  end

  def prior_achievement
    Achievement.where(:id => self.prior).first
  end

  def trajectory(list = [])
    current = self
    limit = 0
    until (prior = current.prior_achievement).nil? or limit > 10
      list << prior.attributes
      current = prior
      limit += 1
    end
    list.reverse!
    list << self.attributes.merge({:current => true})
    current = self
    limit = 0
    until (na = current.next_achievement).nil? or limit > 10
      list << na.attributes
      current = na
      limit += 1
    end
    list
  end
end
