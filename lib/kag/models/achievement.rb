require 'kag/models/model'

class Achievement < KAG::Model
  has_many :user_achievements

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
  end

  def grant(user)
    puts "Granting #{self.code} to #{user.name}"
    ua = ::UserAchievement.new
    ua.user_id = user.id
    ua.achievement_id = self.id
    ua.save
  end

  def users
    User.joins(:user_achievements).where(:user_achievements => {:achievement_id => self.id})
  end

  def users_as_list
    l = []
    self.users.each do |u|
      l << u.name
    end
    l
  end
end
