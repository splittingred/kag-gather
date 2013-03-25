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
        reply m,KAG::Stats::Main.instance.to_s
      end
    end
  end
end