require 'kag/help/book'
require 'kag/models/ignore'
require 'cinch'

module KAG
  module Common
    include Cinch::Plugin

    def reply(message,text,colorize = true)
      text = Format(:grey,text) if colorize
      message.reply text
    end

    def send_channels_msg(msg,colorize = true,notice = false)
      KAG::Config.instance[:channels].each do |c|
        msg = Format(:grey,msg) if colorize
        Channel(c).send(msg,notice)
      end
    end

    def is_banned?(user)
      if user.authed?
        if ::Ignore.is_ignored?(user.authname)
          puts "#{user.authname} is banned"
          true
        else
          false
        end
      else
        puts "user is not authed and therefore not banned"
        false
      end
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
      KAG.ensure_database
    end
  end
end