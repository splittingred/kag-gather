require 'kag/models/model'

class Ignore < KAG::Model
  belongs_to :user

  class << self

    attr_accessor :_cache, :cached

    ##
    # See if the user is banned
    #
    # @param [User] user
    # @return [Boolean] True if banned
    #
    def is_ignored?(user)
      unless Ignore.cached
        Ignore._fetch_cache
      end
      if user.respond_to?(:kag_user)
        Ignore._cache.include?(user.kag_user)
      else
        false
      end
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
      user = User.fetch(user) unless user.class == User

      ig = Ignore.new
      unless creator.nil?
        creator = User.fetch(creator)
        ig.created_by = creator.id
      end
      ig.user_id = user.id
      ig.reason = reason.to_s
      ig.hours = hours.to_i
      ig.created_at = Time.now
      ig.ends_at = Time.now + (hours.to_i * 3600)
      saved = ig.save
      if saved
        user.inc_stat(:ignored)
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
      user = User.fetch(user) unless user.class == User
      ig = Ignore.joins(:user).where(:users => {:kag_user => user.kag_user})
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
      Ignore._cache = Ignore.joins(:user).pluck(:kag_user)
      Ignore.cached = true
    end

    def list
      bans = Ignore.select('ignores.*,users.kag_user').joins(:user).where('ignores.ends_at IS NULL OR ignores.ends_at > ?',Time.now.to_s(:db))
      l = []
      bans.each do |b|
        l << "#{b.kag_user}: for '#{b.reason}' ending at: #{b.ends_at.to_s(:long)}"
      end
      l.join('; ')
    end
  end

end