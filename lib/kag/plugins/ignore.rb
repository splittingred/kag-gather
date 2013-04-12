require 'cinch'
require 'kag/common'
require 'commands/help'

module KAG
  module Ignore
    class Plugin
      include Cinch::Plugin
      include Cinch::Commands
      include KAG::Common
      hook :pre,method: :auth

      command :report,{nick: :string,reason: :string},
        summary: "Report a user the bot"
      def report(m,nick,reason = '')
        if is_admin(m.user)
          u = User(nick)
          if u and !u.unknown
            if ::IgnoreReport.create(u,m.user,reason)
              reply m,"#{nick} has now been reported for \"#{reason}\"."
            end
          else
            reply m,"User #{nick} not found!"
          end
        end
      end

      command :unreport,{nick: :string},
        summary: "Clear your report for a user"
      def unreport(m,nick)
        if is_admin(m.user)
          u = User(nick)
          if u and !u.unknown
            if ::IgnoreReport.unreport(u,m.user)
              reply m,"Your reports have been cleared for #{nick}."
            end
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

      command :clear_reports,{nick: :string},
        summary: "Clear all reports for a given user",
        admin: true
      def clear_reports(m,nick)
        if is_admin(m.user)
          user = User(nick)
          if user and !user.unknown
            if ::IgnoreReport.clear(user)
              reply m,"#{nick} has now been unreported."
            end
          else
            reply m,"Could not find user #{nick}"
          end
        end
      end

      command :ban_list,{},
        summary: "Shows a list of ignored users",
        admin: true
      def ban_list(m)
        if is_admin(m.user)
          reply m,"Banned: "+::Ignore.list
        end
      end

      command :ban,{nick: :string,hours: :integer,reason: :string},
        summary: "Ignore (Ban) a user",
        admin: true
      def ban(m,nick,hours,reason = '')
        if is_admin(m.user)
          user = User(nick)
          if user and !user.unknown
            if ::Ignore.them(user,hours,reason,m.user)
              reply m,"#{nick} has now been banned for #{hours} hours."
            end
          else
            reply m,"Could not find user #{nick}"
          end
        end
      end

      command :unban,{nick: :string},
        summary: "Unignore (Unban) a user",
        admin: true
      def unban(m,nick)
        if is_admin(m.user)
          user = User(nick)
          if user and !user.unknown
            if ::Ignore.unignore(user)
              reply m,"#{nick} has now been unbanned."
            end
          else
            reply m,"Could not find user #{nick}"
          end
        end
      end

    end
  end
end
