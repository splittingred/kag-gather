require 'cinch'
require 'kag/common'
require 'commands/help'

module KAG
  module Bot
    class Plugin
      include Cinch::Plugin
      include Cinch::Commands
      include KAG::Common

      listen_to :connect, :method => :on_connect
      def on_connect(m)
        m.bot.set_mode("x")
      end

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
          if m.bot
            m.bot.quit "Restarting! Back in a second!"
          end
          sleep(0.5)
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

      command :bot_mode,{mode: :string},
        summary:"Set a mode on the bot",
        admin:true
      def bot_mode(m,mode)
        if is_admin(m.user)
          m.bot.set_mode(mode.to_s)
        end
      end

      command :bot_join,{channel: :string,password: :string},
        summary:"Tell the bot to join a channel",
        admin:true
      def bot_join(m,channel,password = nil)
        if is_admin(m.user)
          m.bot.join(channel,password)
        end
      end

      command :bot_part,{channel: :string,reason: :string},
        summary:"Tell the bot to part a channel",
        admin:true
      def bot_part(m,channel,reason = nil)
        if is_admin(m.user)
          m.bot.part(channel,reason)
        end
      end
    end
  end
end