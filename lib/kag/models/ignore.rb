require 'kag/models/model'

class Ignore < KAG::Model
  belongs_to :user

  class << self

    attr_accessor :_cache, :cached

    ##
    # See if the user is banned
    #
    # @param [String] authname
    # @return [Boolean] True if banned
    #
    def is_ignored?(authname)
      unless Ignore.cached
        Ignore._fetch_cache
      end
      Ignore._cache.include?(authname)
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
        Ignore._fetch_cache
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
      ig = Ignore.joins(:user).where(:users => {:authname => user})
      if ig
        ig.each do |ignore|
          ignore.destroy
        end
        Ignore._fetch_cache
        true
      else
        false
      end
    end

    ##
    # Refreshes cache
    #
    def refresh
      Ignore._fetch_cache
    end

    ##
    # Cache the ignore list into an array for easier lookup
    #
    def _fetch_cache
      Ignore._cache = Ignore.joins(:user).pluck(:authname)
      Ignore.cached = true
    end

    def list
      Ignore.joins(:user).pluck(:authname).join(", ")
    end
  end

end