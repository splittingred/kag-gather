require 'cinch'
require 'kag/common'
require 'commands/help'

module KAG
  module Bot
    class Plugin
      include Cinch::Plugin
      include Cinch::Commands
      include KAG::Common

      command :quit,{},
        summary: "Quit the bot",
        admin: true
      def quit(m)
        if is_admin(m.user)
          m.bot.quit("Shutting down...")
        end
      end

      match "restart", :method => :evt_restart
      def evt_restart(m)
        if is_admin(m.user)
          cmd = (KAG::Config.instance[:restart_method] or "nohup sh gather.sh &")
          debug cmd
          pid = spawn cmd
          debug "Restarting bot, new process ID is #{pid.to_s} ..."
          exit
        end
      end

      match /is_admin (.+)/, :method => :evt_am_i_admin
      def evt_am_i_admin(m,nick)
        u = User(nick)
        if is_admin(u)
          reply m,"Yes, #{nick} is an admin!"
        else
          reply m,"No, #{nick} is not an admin."
        end
      end

      match "reload_config", :method => :evt_reload_config
      def evt_reload_config(m)
        if is_admin(m.user)
          KAG::Config.instance.reload
          m.reply "Configuration reloaded."
        end
      end
=begin
      match "help", :method => :evt_help
      def evt_help(m)
        unless is_banned?(m.user)
          msg = "Commands: !add, !rem, !list, !status, !help, !end, !report, !reports [nick]"
          msg = msg + ", !rem [nick], !add [nick], !add_silent, !rem_silent, !unreport, !clear, !restart, !quit" if is_admin(m.user)
          User(m.user.nick).send(msg)
        end
      end
=end
    end
  end
end