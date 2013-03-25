require 'cinch'
require 'kag/common'
require 'commands/help'

module KAG
  module Help
    class Plugin
      include Cinch::Plugin
      include Cinch::Commands
      include KAG::Common

      command :help,{},
        summary: "Get general help on KAG Gather",
        admin: true
      def help(m)
        if m.user.authed?
          m.user.send(_h("general_help",{
            :nick => m.user.nick
          }))
        else
          m.user.send(_h("general_not_authed",{
            :nick => m.user.nick
          }))
        end
      end
    end
  end
end