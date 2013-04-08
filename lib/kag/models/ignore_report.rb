require 'kag/models/model'

class IgnoreReport < KAG::Model
  belongs_to :user

  after_save :check_for_ignore_limit

  class << self
    def create(u,creator,reason = '')
      user = User.fetch(u)
      creator = User.fetch(creator)
      if user and creator
        report = IgnoreReport.new
        report.created_by = creator.id
        report.user_id = user.id
        report.reason = reason.to_s
        report.created_at = Time.now
        report.save
      else
        false
      end
    end

    def total_for(u)
      user = User.fetch(u)
      if user
        Ignore.where(:user_id => user.id).count
      else
        0
      end
    end

    def un(user)
      user = User.fetch(user)
      if user
        Ignore.where(:user_id => user.id).each do |r|
          r.destroy
        end
      end
    end
  end

  def check_for_ignore_limit
    if IgnoreReport.where(:user_id => self.user_id).count > KAG::Config.instance[:report_threshold].to_i
      Ignore.them(self.user,24,"Passed report threshold.")
      IgnoreReport.un(self.user)
    end
  end
end