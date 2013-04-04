require 'kag/help/book'

module KAG
  module Common
    include Cinch::Plugin

    def reply(message,text,colorize = true)
      text = Format(:grey,text) if colorize
      message.reply text
    end

    def send_channels_msg(msg,colorize = true)
      KAG::Config.instance[:channels].each do |c|
        msg = Format(:grey,msg) if colorize
        Channel(c).send(msg)
      end
    end

    def is_banned?(user)
      KAG::Bans::Report.is_banned?(user)
    end

    def debug(msg)
      if KAG::Config.instance[:debug]
        puts msg
      end
    end

    def is_admin(user)
      user.refresh
      o = (KAG::Config.instance[:owners] or [])
      o.include?(user.authname)
    end

    def _h(key,params = {})
      if KAG::Help::Book.instance.key?(key.to_sym)
        text = KAG::Help::Book.instance[key.to_sym].to_s
        params.each do |k,v|
          text.gsub!("[[+"+k.to_s+"]]",v)
        end
        text
      else
        ""
      end
    end

    def _load_db
      ActiveRecord::Base.logger = Logger.new('debug.log')
      config = KAG::Config.instance['database']
      #ActiveRecord::Base.configurations = config
      db = config[:development]
      ActiveRecord::Base.establish_connection(
        :adapter => db[:adapter].to_sym,
        :host => db[:host].to_s,
        :database => db[:database].to_s,
        :username => db[:username].to_s,
        :password => db[:password].to_s,
        :pool => db[:pool].to_i,
        :timeout => db[:timeout].to_i

      )
    end
  end
end