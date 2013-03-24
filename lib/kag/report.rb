require 'symboltable'
require 'kag/data'
require 'kag/config'

module KAG
  class Report < SymbolTable

    def initialize(hash=nil)
      super(hash)
      _ensure_data
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

    def data
      KAG::Config.data
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
      data[:reported][self[:authname].to_sym][:count].to_i > KAG::Config.instance[:report_threshold].to_i
    end

    def up_report_count
      data[:reported][self[:authname].to_sym][:count] = data[:reported][self[:authname].to_sym][:count].to_i + 1
      data.save

      gather.reply message,"User #{user.nick} reported. #{user.nick} has now been reported #{data[:reported][self[:authname].to_sym][:count]} times." if gather.class == KAG::Gather
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
  end
end