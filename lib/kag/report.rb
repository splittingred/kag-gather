require 'symboltable'
require 'kag/data'
require 'kag/config'

module KAG
  class Report < SymbolTable

    def initialize(hash=nil)
      super
      KAG::Config.data[:reported] = {} unless KAG::Config.data[:reported]
      KAG::Config.data[:banned] = {} unless KAG::Config.data[:banned]
      if reported?
        if past_threshold?
          ban
        else
          up_report_count
        end
      else
        report
      end
    end

    def reported?
      KAG::Config.data[:reported].has_key?(self[:authname])
    end

    def report
      c = self.clone
      c.delete(:gather)
      c.delete(:message)
      KAG::Config.data[:reported][self[:authname].to_sym] = c
      KAG::Config.data.save
      self[:gather].reply self[:message],"User #{self[:nick]} reported."

    end

    def ban
      c = self.clone
      c.delete(:gather)
      c.delete(:message)
      KAG::Config.data[:banned][self[:authname].to_sym] = c
      self[:gather].reply self[:message],"User #{self[:nick]} banned."
    end

    def past_threshold?
      KAG::Config.data[:reported][self[:authname].to_sym][:count].to_i > KAG::Config.instance[:report_threshold]
    end

    def up_report_count
      KAG::Config.data[:reported][self[:authname].to_sym][:count] = KAG::Config.data[:reported][self[:authname].to_sym][:count].to_i + 1
    end

    def self.remove(user,message,gather)
      if KAG::Config.data[:reported] and KAG::Config.data[:reported].has_key?(user.authname)
        KAG::Config.data[:reported].delete(user.authname)
        gather.reply message,"User #{user.nick} removed from report list."
      else
        gather.reply message,"User #{user.nick} not in report list!"
      end
    end
  end
end