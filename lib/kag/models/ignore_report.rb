require 'kag/models/model'
require 'kag/models/user'

class IgnoreReport < KAG::Model
  belongs_to :user
  belongs_to :creator, :class_name => User, :foreign_key => "created_by"

  after_save :check_for_ignore_limit

  class << self
    def create(u,creator,reason = '')
      user = User.fetch(u)
      creator = User.fetch(creator)
      if user and creator
        if IgnoreReport.exists(user,creator)
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
      user = User.fetch(user)
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
    def unreport(user,do_stats = true)
      user = User.fetch(user)
      if user
        IgnoreReport.where(:user_id => user.id).each do |r|
          if do_stats
            r.user.dec_stat(:reported)
            r.creator.dec_stat(:reported_others)
          end
          r.destroy
        end
      end
    end
  end

  ##
  # Check to see if a user has reached the report limit; if so, then ignore them and clear reports
  #
  def check_for_ignore_limit
    if IgnoreReport.where(:user_id => self.user_id).count > KAG::Config.instance[:report_threshold].to_i
      Ignore.them(self.user,24,"Passed report threshold.")
      IgnoreReport.unreport(self.user,false)
    end
  end
end