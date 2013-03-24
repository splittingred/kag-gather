require 'symboltable'
require 'kag/data'
require 'kag/config'

module KAG
  class Report < SymbolTable

    def initialize(hash=nil)
      super(hash)
      _ensure_data
      if reported?
        if can_report?
          if past_threshold?
            ban
          else
            up_report_count
          end
        else
          self[:gather].reply self[:message],"You have already reported #{self[:nick]}. You can only report a user once."
        end
      else
        report
      end
    end

    def can_report?
      r = _report
      if r and r[:reporters]
        !r[:reporters].include?(self[:message].user.authname)
      else
        true
      end
    end


    def _ensure_data
      data[:reported] = {} unless data[:reported]
      data[:banned] = {} unless data[:banned]
    end

    def reported?
      data[:reported].key?(self[:authname].to_sym)
    end

    def report
      c = self.clone
      c.delete(:gather)
      c.delete(:message)
      c[:reporters] = [self[:message].user[:authname]]
      data[:reported][self[:authname].to_sym] = c
      data.save

      self[:gather].reply self[:message],"User #{self[:nick]} reported." if self[:gather].class == KAG::Gather
    end

    def ban
      c = self.clone
      c.delete(:gather)
      c.delete(:message)
      data[:banned][self[:authname].to_sym] = c
      data.save
      self[:gather].reply self[:message],"User #{self[:nick]} banned." if gather.class == KAG::Gather
    end

    def past_threshold?
      _report[:count].to_i > KAG::Config.instance[:report_threshold].to_i
    end

    def up_report_count
      _report[:count] = _report[:count].to_i + 1
      _report[:reporters] = [] unless _report[:reporters]
      _report[:reporters] << self[:message].user.authname
      data.save

      gather.reply message,"User #{self[:nick]} reported. #{self[:nick]} has now been reported #{data[:reported][self[:authname].to_sym][:count]} times." if gather.class == KAG::Gather
    end


    def self.remove(user,message,gather)
      data = KAG::Config.data
      if data[:reported] and data[:reported].key?(user.authname.to_sym)
        data[:reported].delete(user.authname)

        gather.reply message,"User #{user.nick} removed from report list." if gather.class == KAG::Gather
        true
      else
        gather.reply message,"User #{user.nick} not in report list!" if gather.class == KAG::Gather
        false
      end
    end

    protected

    def data
      KAG::Config.data
    end

    def _report
      data[:reported][self[:authname].to_sym]
    end
  end
end