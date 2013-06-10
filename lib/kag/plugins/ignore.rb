require 'cinch'
require 'kag/common'
require 'commands/help'

module KAG
  module Ignore
    class Plugin
      include Cinch::Plugin
      include Cinch::Commands
      include KAG::Common
      hook :pre,method: :auth
      hook :post, method: :close_db_connection

      command :report,{kag_user: :string,reason: :string},
        regexp: /report ((?:\w+\S){2})(.*)/i,
        summary: 'Report a user the bot'
      def report(m,kag_user,reason = '')
        if is_admin(m.user)
          reason = reason.to_s.strip
          user = ::User.fetch(kag_user)
          unless user
            user = ::User.new
            user.kag_user = kag_user
            user.created_at = Time.now
            user.save
          end
          if ::IgnoreReport.create(user,m.user,reason)
            reply m,"#{kag_user} has now been reported for \"#{reason}\"."
          else
            reply m,"Failed to create ban for #{kag_user}"
          end
        end
      end

      command :unreport,{kag_user: :string},
        summary: 'Clear your reports for a user'
      def unreport(m,kag_user)
        if is_admin(m.user)
          user = ::User.fetch(kag_user)
          if user
            if ::IgnoreReport.unreport(user,m.user)
              reply m,"Your reports have been cleared for #{kag_user}."
            end
          else
            reply m,"User #{kag_user} not found!"
          end
        end
      end

      command :reports,{kag_user: :string},
        summary: 'Show the number of reports for a given user'
      def reports(m,kag_user)
        user = ::User.fetch(kag_user)
        if user
          count = ::IgnoreReport.total_for(user)
          if count
            reply m,"User #{kag_user} has been reported #{count.to_s} times."
          else
            reply m,"User #{kag_user} has not been reported."
          end
        else
          reply m,"Could not find user #{kag_user}"
        end
      end

      command :clear_reports,{kag_user: :string},
        summary: 'Clear all reports for a given user',
        admin: true
      def clear_reports(m,kag_user)
        if is_admin(m.user)
          user = ::User.fetch(kag_user)
          if user
            if ::IgnoreReport.clear(user)
              reply m,"#{nick} has now been unreported."
            end
          else
            reply m,"Could not find user #{nick}"
          end
        end
      end

      command :ban_list,{},
        summary: 'Shows a list of ignored users',
        admin: true
      def ban_list(m)
        if is_admin(m.user)
          reply m,'Banned: '+::Ignore.list
        end
      end

      command :ban,{kag_user: :string,hours: :integer,reason: :string},
        regexp: /ban ([\w\._\-]{1,50}) ?([0-9]{1,})?(.*)/i,
        summary: 'Ignore (Ban) a user',
        admin: true
      def ban(m,kag_user,hours,reason = '')
        if is_admin(m.user)
          reason = reason.to_s.strip
          user = ::User.fetch(kag_user)
          if user
            if ::Ignore.them(user,hours,reason,m.user)
              reply m,"#{kag_user} has now been banned for #{hours.to_s} hours."
            end
          else
            reply m,"Could not find user #{kag_user}"
          end
        end
      end

      command :unban,{kag_user: :string},
        summary: 'Unignore (Unban) a user',
        admin: true
      def unban(m,kag_user)
        if is_admin(m.user)
          user = ::User.fetch(kag_user)
          if user
            if ::Ignore.unignore(user)
              reply m,"#{kag_user} has now been unbanned."
            end
          else
            reply m,"Could not find user #{kag_user}"
          end
        end
      end

      command :refresh_ban_cache,{},
        summary: 'Refresh ban list',
        admin: true
      def refresh_ban_cache(m)
        ::Ignore.refresh
      end
    end
  end
end
