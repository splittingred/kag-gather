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

      command :restart,{},
        summary: "Restart the bot",
        admin: true
      def restart(m)
        if is_admin(m.user)
          cmd = (KAG::Config.instance[:restart_method] or "nohup sh gather.sh &")
          debug cmd
          pid = spawn cmd
          debug "Restarting bot, new process ID is #{pid.to_s} ..."
          exit
        end
      end

      command :is_an_admin,{nick: :string},
        summary: "See if the specified user is an Admin"
      def is_an_admin(m,nick)
        u = User(nick)
        if is_admin(u)
          reply m,"Yes, #{nick} is an admin!"
        else
          reply m,"No, #{nick} is not an admin."
        end
      end

      command :reload_config,{},
        summary: "Reload the configuration file",
        admin: true
      def reload_config(m)
        if is_admin(m.user)
          KAG::Config.instance.reload
          m.reply "Configuration reloaded."
        end
      end

      command :version,{},
        summary: "Show the version of the bot",
        admin: true
      def version(m)
        if is_admin(m.user)
          require 'kag/version'
          m.reply "KAG Gather - version "+KAG::VERSION.to_s+" by splittingred - https://github.com/splittingred/kag-gather"
        end
      end
    end
  end
end