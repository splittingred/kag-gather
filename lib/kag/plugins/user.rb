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
        summary: "See if your IRC account is linked to your KAG Account."
      def linked?(m)
        if m.user.authed?
          u = ::User.find_by_authname(m.user.authname)
          if u and u.linked?
            m.user.send("Your IRC user #{m.user.authname} is linked to the KAG account #{u.kag_user.to_s}")
          else
            m.user.send("Your IRC user #{m.user.authname} is not linked to any KAG account.")
          end
        else
          m.user.send("You will need to AUTH with IRC before linking. Do !help for more information.")
        end
      end

      command :link,{},
        summary: "Link your IRC user to your KAG account for stats tracking and other cool features..",
        description: "Link your IRC Auth to your KAG account. This is only required to do once."
      def link(m)
        if m.user.authed?
          u = ::User.find_by_authname(m.user.authname)
          unless u
            u = ::User.create(m.user)
          end

          if u.linked?
            m.user.send("Your IRC user #{m.user.authname} is already linked to the KAG account #{u.kag_user.to_s}")
          else
            m.user.send("Please go to http://stats.gather.kag2d.nl/sso/?i=#{m.user.authname} to link your main KAG Account with your KAG-Gather account. This will redirect you to a secure, official KAG-sponsored SSO site that keeps your information secure and only on the kag2d.com servers.")
          end
        else
          m.user.send("You will need to AUTH with IRC before linking. Do !help for more information.")
        end
      end

      command :unlink,{},
        summary: "Unlink your IRC user from a KAG account",
        description: "This will unlink your IRC AUTH user from a KAG account."
      def unlink(m)
        if m.user.authed?
          u = ::User.find_by_authname(m.user.authname)
          if u and u.linked?
            if u.unlink
              m.user.send("Your IRC user #{m.user.authname} has been unlinked to your KAG account.")
            end
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