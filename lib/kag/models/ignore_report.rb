require 'kag/models/model'
require 'kag/models/user'

class IgnoreReport < KAG::Model
  belongs_to :user
  belongs_to :creator, :class_name => User, :foreign_key => "created_by"

  after_save :check_for_ignore_limit

  class << self
    def create(user,c,reason = '')
      user = User.fetch(user) unless user.class == User
      creator = User.fetch(c)
      if user and creator
        if false#IgnoreReport.exists(user,creator)
          false
        else
          report = IgnoreReport.new
          report.created_by = creator.id
          report.user_id = user.id
          report.reason = reason.to_s
          if report.save
            user.inc_stat(:reported)
            creator.inc_stat(:reported_others)
            true
          end
        end
      else
        c.send 'Could not find your User!' unless creator
        c.send 'Could not find User to ban!' unless user
        false
      end
    end

    ##
    # See if a report already exists for a user by a person
    #
    # @param [User] user
    # @param [User] creator
    # @return [Boolean]
    #
    def exists(user,creator)
      IgnoreReport.where(:user_id => user.id,:created_by => creator.id).count > 0
    end

    ##
    # Return the total number of reports for a given user
    #
    # @param [User|String|Cinch::User] user
    # @return [Integer]
    #
    def total_for(user)
      user = User.fetch(user) unless user.class == User
      if user
        IgnoreReport.where(:user_id => user.id).count
      else
        0
      end
    end

    ##
    # Remove all reports for a user
    #
    # @param [User|String|Cinch::User] user
    # @param [Boolean] do_stats If true, adjust stats of creator/user
    #
    def clear(user,do_stats = true)
      user = User.fetch(user) unless user.class == User
      if user
        IgnoreReport.where(:user_id => user.id).each do |r|
          if do_stats
            r.user.dec_stat(:reported) if r.user
            r.creator.dec_stat(:reported_others) if r.creator
          end
          r.destroy
        end
      end
    end

    def unreport(user,reporter,do_stats = true)
      user = User.fetch(user) unless user.class == User
      reporter = User.fetch(reporter)
      if user and reporter
        IgnoreReport.where(:user_id => user.id,:created_by => reporter.id).each do |r|
          if do_stats
            r.user.dec_stat(:reported) if r.user
            r.creator.dec_stat(:reported_others) if r.creator
          end
          r.destroy
        end
      end
    end
  end

  ##
  # Calculate ban points and issue ban if needed
  #
  def check_for_ignore_limit
    ban_points = IgnoreReport.where(:user_id => self.user_id).count
    #matches_count = self.user.matches.count

    matches_count = 4

    match_leniency = 2.5
    num_days = 1
    ban_time = ((24*num_days) * (ban_points - (matches_count / match_leniency)) * (1.2 ** ban_points)).floor

    if ban_time > 0
      Ignore.them(self.user,ban_time,"Temporary ban for exceeding ban points. Matches: #{matches_count}, Ban Points: #{ban_points}")
      KAG.gather.send_channels_msg "#{self.user.name} has been temporarily banned for #{ban_time} hours for exceeding ban points."
    end
  end
end