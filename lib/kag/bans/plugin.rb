require 'cinch'
require 'kag/common'

module KAG
  module Bans
    class Plugin
      include Cinch::Plugin
      include KAG::Common

      match /report (.+)/,:method => :report
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

      match /reports (.+)/,:method => :reports
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

      match "reported",:method => :reported
      def reported(m)
        unless is_banned?(m.user)
          KAG::Bans::Report.list
        end
      end

      match /unreport (.+)/,:method => :unreport
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

      match /ignore (.+)/,:method => :ignore
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

      match /unignore (.+)/,:method => :unignore
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
