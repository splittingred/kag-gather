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
      hook :pre,method: :auth

      command :stats,{},
        summary: 'Get the gather-wide stats'
      def stats(m)
        reply m,KAG::Stats::Main.instance.collect { |k,v| "#{k}: #{v}" }.join(", ")
      end

      command :stats,{name: :string},
        summary: 'Get the stats for a user',
        method: :stats_specific
      def stats_specific(m,name)
        unless is_banned?(m.user)
          u = ::User.fetch(name)
          if u
            m.user.send u.stats_text
          else
            reply m,"User #{name} has not played any matches, and therefore is not in the stats table."
          end
        end
      end
    end
  end
end