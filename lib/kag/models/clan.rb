require 'kag/models/model'

class Clan < KAG::Model
  has_many :users
  has_many :clan_stats

  class << self

    def fetch(name)
      clan = ::Clan.find_by_name(name)
      unless clan
        clan = ::Clan.new
        clan.name = name
        unless clan.save
          clan = nil
        end
      end
      clan
    end
  end

  def add_member(user)
    success = false
    user = User.fetch(user) unless user.class == User
    if user and user.clan_id != self.id
      user.clan_id = self.id
      success = user.save
    end
    success
  end

  ##
  # Get the stats for the Clan
  #
  # @param [Boolean] bust_cache
  # @return [Array]
  #
  def stats(bust_cache = true)
    ClanStat.select('*,(SELECT (COUNT(*)+1) FROM `clan_stats` AS `us2` WHERE `us2`.`name` = `clan_stats`.`name` AND `us2`.`clan_id` != '+self.id.to_s+' AND `us2`.`value` > `clan_stats`.`value` ) AS `rank`').where('clan_id = ?',self.id)
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
  # Set the stat for the clan for a key
  #
  # @param [String|Symbol] k
  # @param [Integer|Float|String] v
  # @return [Boolean]
  #
  def set_stat(k,v)
    s = self.stat(k,false)
    unless s
      s = ClanStat.new({
        :clan => self,
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
      s = ClanStat.new({
        :clan => self,
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
      s = ClanStat.new({
        :clan => self,
        :name => k.to_s,
        :value => 0,
      })
    end
    s.value = s.value.to_i-decrement.to_i
    s.save
  end
end
