require 'cinch'
require 'kag/common'
require 'commands/help'
require 'kag/user/user'

module KAG
  module User
    class Plugin
      include Cinch::Plugin
      include Cinch::Commands
      include KAG::Common

      command :stats,{},
        summary: "Get the stats for a user"
      def stats(m)
        reply m,KAG::User::User.stats(m.user)
      end

      command :stats,{nick: :string},
        summary: "Get the stats for a user",
        method: :stats_specific
      def stats_specific(m,nick)
        user = User(nick)
        if user and !user.unknown
          reply m,KAG::User::User.stats(user)
        else
          reply m,"Could not find user #{nick}"
        end
      end
    end
  end
end