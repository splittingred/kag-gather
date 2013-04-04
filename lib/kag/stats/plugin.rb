require 'cinch'
require 'kag/common'
require 'commands/help'
require 'kag/user/user'
require 'kag/stats/main'

module KAG
  module Stats
    class Plugin
      include Cinch::Plugin
      include Cinch::Commands
      include KAG::Common

      command :stats,{},
        summary: "Get the gather-wide stats"
      def stats(m)
        reply m,KAG::Stats::Main.instance.collect { |k,v| "#{k}: #{v}" }.join(", ")
      end

      command :stats,{nick: :string},
        summary: "Get the stats for a user",
        method: :stats_specific
      def stats_specific(m,nick)
        user = User(nick)
        if user and !user.unknown
          u = ::User.find_by_authname(user.authname)
          if u
            reply m,u.stats
          else
            reply m,"User has not played any matches, and therefore is not in the stats table."
          end
        else
          reply m,"Could not find user #{nick}"
        end
      end
    end
  end
end