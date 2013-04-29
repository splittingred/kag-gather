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
      hook :post, method: :close_db_connection

      # every 15 min clear temps
      timer 600, method: :clear_expired_logins
      def clear_expired_logins
        ::User.clear_expired_logins
      end


      listen_to :nick, method: :on_nick
      def on_nick(m)
        m.user.refresh
      end

      command :login,{},
        summary: 'Login to Gather through the KAG SSO'
      def login(m)
        unless is_banned?(m.user)
          if m.user.authed?
            u = ::User.fetch(m.user)
            if u and u.linked?
              m.user.send 'You are already AUTHed and linked via AUTH. No need to !login.'
            elsif u
              m.user.send 'You are already AUTHed, so you just need to !link to proceed.'
            else
              ::User.login(m)
            end
          else
            ::User.login(m)
          end
        end
      end

      command :linked?,{},
        summary: 'See if your IRC account is linked to your KAG Account.'
      def linked?(m)
        if m.user.authed?
          u = ::User.find_by_authname(m.user.authname)
          if u and u.linked?
            m.user.send("Your IRC user #{m.user.authname} is linked to the KAG account #{u.kag_user.to_s}")
          else
            m.user.send("Your IRC user #{m.user.authname} is not linked to any KAG account.")
          end
        else
          m.user.send('You will need to AUTH with IRC before linking. Do !help for more information.')
        end
      end

      command :mlink,{nick: :string, kag_user: :string},
        summary: 'Manually link a nick to a KAG account. Only do this if an emergency, as this could allow ppl to spoof others.',
        admin: true
      def mlink(m,nick,kag_user)
        nick = nick.to_s.strip
        kag_user = kag_user.to_s.strip
        u = User(nick)
        if u
          user = ::User.new
          user.authname = u.authname if u.authed?
          user.kag_user = kag_user
          user.host = user.host
          user.created_at = Time.now
          user.save
          m.reply "#{nick} linked to KAG account #{kag_user}"
        else
          m.reply "Could not find user #{nick}"
        end
      end

      command :link,{},
        summary: 'Link your IRC user to your KAG account for stats tracking and other cool features..',
        description: 'Link your IRC Auth to your KAG account. This is only required to do once.'
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
          m.user.send('You will need to AUTH with IRC before linking. Do !help for more information.')
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