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
      proceed = false
      if m.params.length > 0 and ['Quit','Part','Kick','Kill','EOF from client','Read error: EOF from client','Ping timeout','Read error: Connection reset by peer','Signed off','Read error: Operation timed out'].include?(m.params[0])
        proceed = true
      else
        if m.user
          if is_banned?(m.user)
            puts "#{m.user.nick} is banned and cannot use the bot."
          elsif m.user.authed?
            proceed = true
          elsif self.class.name.to_s != "KAG::Help::Plugin" and self.class.name.to_s != "KAG::IRC::Plugin"
            u = ::User.fetch(m.user)
            if u
              proceed = true
            else
              send_not_authed_msg(m)
            end
          else
            proceed = true
          end
        end
      end
      puts "Proceed: #{proceed.to_s}"
      proceed
    end

    def close_db_connection(m)
      begin
        ::ActiveRecord::Base.connection.close
      rescue Exception => e
        puts e.message
        puts e.backtrace.join("\n")
      end
      true
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
        u = ::User.fetch(user)
        if u and ::Ignore.is_ignored?(u)
          puts "#{u.kag_user} is banned"
          true
        else
          false
        end
      else
        false
      end
    end

    def send_not_authed_msg(m)
      puts "sending not authed to #{m.user.nick}"
      m.user.send _h('command_not_authed')
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
          text = text.gsub("[[+#{k.to_s}]]",v)
        end
        text
      else
        ''
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