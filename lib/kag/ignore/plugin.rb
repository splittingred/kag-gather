require 'cinch'
require 'kag/common'
require 'commands/help'

module KAG
  module Ignore
    class Plugin
      include Cinch::Plugin
      include Cinch::Commands
      include KAG::Common

      command :report,{nick: :string,reason: :string},
        summary: "Report a user the bot"
      def report(m,nick,reason = '')
        unless is_banned?(m.user)
          u = User(nick)
          if u and !u.unknown
            ::IgnoreReport.create(u,m.user,reason)
            KAG::Bans::Report.new(self,m,u)
          else
            reply m,"User #{nick} not found!"
          end
        end
      end

      command :reports,{nick: :string},
        summary: "Show the number of reports for a given user"
      def reports(m,nick)
        user = User(nick)
        if user and !user.unknown
          count = ::IgnoreReport.total_for(user)
          if count
            reply m,"User has been reported #{count.to_s} times."
          else
            reply m,"User has not been reported."
          end
        else
          reply m,"Could not find user #{nick}"
        end
      end

      command :unreport,{nick: :string},
        summary: "Clear all reports for a given user",
        admin: true
      def unreport(m,nick)
        if is_admin(m.user)
          user = User(nick)
          if user and !user.unknown
            ::IgnoreReport.un(user)
          else
            reply m,"Could not find user #{nick}"
          end
        end
      end

      command :ignore,{nick: :string,hours: :int,reason: :string},
        summary: "Ignore (Ban) a user",
        admin: true
      def ignore(m,nick,hours,reason = '')
        if is_admin(m.user)
          user = User(nick)
          if user and !user.unknown
            ::Ignore.them(user,hours,reason,m.user)
          else
            reply m,"Could not find user #{nick}"
          end
        end
      end

      command :unignore,{nick: :string},
        summary: "Unignore (Unban) a user",
        admin: true
      def unignore(m,nick)
        if is_admin(m.user)
          user = User(nick)
          if user and !user.unknown
            ::Ignore.un(user)
          else
            reply m,"Could not find user #{nick}"
          end
        end
      end

    end
  end
end
