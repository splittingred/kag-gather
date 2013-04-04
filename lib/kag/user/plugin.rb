require 'cinch'
require 'kag/common'
require 'commands/help'
require 'kag/user/user'
require 'kag/user/linker'

module KAG
  module User
    class Plugin
      include Cinch::Plugin
      include Cinch::Commands
      include KAG::Common

      command :linked?,{},
        summary: "See if your IRC account is linked."
      def linked?(m)
        if m.user.authed?
          unlinked = KAG::User::Linker.unlinked?(m.user)
          if unlinked === true
            m.user.send("Your IRC user #{m.user.authname} is not linked to any KAG account.")
          else
            m.user.send("Your IRC user #{m.user.authname} is linked to the KAG account #{unlinked.to_s}")
          end
        else
          m.user.send("You will need to AUTH with IRC before linking. Do !help for more information.")
        end
      end

      command :link,{username: :string,password: :string},
        summary: "Link your IRC user to your KAG account",
        description: "Enter in your KAG username and password to link your IRC Auth to your KAG account. This is only required to do once."
      def link(m,username,password)
        if m.user.authed?
          unlinked = KAG::User::Linker.unlinked?(m.user)
          if unlinked === true
            KAG::User::Linker.link(m.user,username,password)
          else
            m.user.send("Your IRC user #{m.user.authname} is already linked to the KAG account #{unlinked.to_s}")
          end
        else
          m.user.send("You will need to AUTH with IRC before linking. Do !help for more information.")
        end
      end

      command :unlink,{username: :string},
        summary: "Unlink your IRC user from a KAG account",
        description: "This will unlink your IRC AUTH user from a KAG account."
      def unlink(m,username)
        if m.user.authed?
          unlinked = KAG::User::Linker.unlinked?(m.user)
          if unlinked != true
            KAG::User::Linker.unlink(m.user,username)
          else
            m.user.send("Your IRC user #{m.user.authname} is not linked to any KAG account.")
          end
        else
          m.user.send("You will need to AUTH with IRC before linking. Do !help for more information.")
        end

      end
    end
  end
end