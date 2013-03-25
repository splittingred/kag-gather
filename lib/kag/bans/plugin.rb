require 'cinch'
require 'kag/common'

module KAG
  module Bans
    class Plugin
      include Cinch::Plugin
      include KAG::Common

      command :report,{nick: :string},
        summary: "Report a user the bot"
      def report(m,nick)
        unless is_banned?(m.user)
          u = User(nick)
          if u and !u.unknown
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
          count = KAG::Bans::Report.reports(user)
          if count
            reply m,"User has been reported #{count.to_s} times."
          else
            reply m,"User has not been reported."
          end
        else
          reply m,"Could not find user #{nick}"
        end
      end

      command :reported,{},
        summary: "Show a list of reported users"
      def reported(m)
        unless is_banned?(m.user)
          KAG::Bans::Report.list
        end
      end

      command :unreport,{nick: :string},
        summary: "Clear all reports for a given user",
        admin: true
      def unreport(m,nick)
        if is_admin(m.user)
          user = User(nick)
          if user and !user.unknown
            KAG::Bans::Report.remove(self,m,user)
          else
            reply m,"Could not find user #{nick}"
          end
        end
      end

      command :ignore,{nick: :string},
        summary: "Ignore (Ban) a user",
        admin: true
      def ignore(m,nick)
        if is_admin(m.user)
          user = User(nick)
          if user and !user.unknown
            KAG::Bans::Report.ignore(self,m,user)
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
            KAG::Bans::Report.unignore(self,m,user)
          else
            reply m,"Could not find user #{nick}"
          end
        end
      end

    end
  end
end
