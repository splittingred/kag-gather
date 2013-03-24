
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
  end
end