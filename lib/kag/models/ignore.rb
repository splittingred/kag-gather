require 'kag/models/model'

class Ignore < KAG::Model
  belongs_to :user

  attr_accessor :cache, :cached

  class << self
    ##
    # See if the user is banned
    #
    # @param [String] authname
    # @return [Boolean] True if banned
    #
    def is?(authname)
      unless self.cached
        self._fetch_cache
      end
      self.cache.include?(authname)
    end

    ##
    # Ban a user
    #
    # @param [String|Cinch::User] user The user or authname to ban
    # @param [Integer] hours How many hours to ban
    # @param [String] reason The reason for the ban
    # @param [String|Cinch::User] creator The creator of the ban, if any
    # @return [Boolean]
    #
    def them(user,hours,reason = '',creator = nil)
      unless user.class == String
        return false unless user.authed?
        user = user.authname
      end
      u = User.fetch(user)

      ig = Ignore.new
      unless creator.nil?
        creator = User.fetch(creator)
        ig.created_by = creator.id
      end
      ig.user_id = u.id
      ig.reason = reason.to_s
      ig.hours = hours.to_i
      ig.created_at = Time.now
      ig.ends_at = Time.now + (hours.to_i * 3600)
      saved = ig.save
      if saved
        u.inc_stat(:ignored)
        creator.inc_stat(:ignored_others) if creator
      else
        false
      end
    end

    ##
    # Unban a user
    #
    # @param [String|Cinch::User] user The user or authname to unban
    def unignore(user)
      unless user.class == String
        return false unless user.authed?
        user = user.authname
      end
      ig = Ignore.joins(:user).where(:user => {:authname => user})
      if ig
        ig.destroy
        true
      else
        false
      end
    end

    protected

    ##
    # Cache the ignore list into an array for easier lookup
    #
    def _fetch_cache
      self.cache = Ignore.joins(:user).pluck(:authname)
      self.cached = true
    end
  end

end