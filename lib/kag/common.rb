require 'kag/help/book'
require 'kag/models/ignore'
require 'cinch'

module KAG
  module Common
    include Cinch::Plugin
    ##
    # Prevent non-authed or banned users from using bot
    #
    def auth(m)
      if m.params.length > 0 and ['Quit','Part','Kick','Kill','EOF from client','Read error: EOF from client','Ping timeout'].include?(m.params[0])
        true
      else
        if m.user
          if is_banned?(m.user)
            false
          elsif m.user.authed?
            true
          elsif self.class.name.to_s != "KAG::Help::Plugin" and self.class.name.to_s != "KAG::IRC::Plugin"
            send_not_authed_msg(m)
            false
          else
            true
          end
        else
          false
        end
      end
    end

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

    def send_not_authed_msg(m)
      m.user.send _h("command_not_authed")
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
          text = text.gsub("[[+"+k.to_s+"]]",v)
        end
        text
      else
        ""
      end
    end

    def _load_db
      KAG.ensure_database
    end

    def _close_db
      begin
        ActiveRecord::Base.connection.close
      rescue Exception => e
        puts e.message
        puts e.backtrace.join("\n")
      end
    end
  end
end