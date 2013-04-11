require 'cinch'
require 'kag/common'
require 'commands/help'
require 'kag/bot/bot'

module KAG
  module Gather
    class Plugin
      include Cinch::Plugin
      include Cinch::Commands
      include KAG::Common

      #ActiveRecord::Base.connection.close

      attr_accessor :queue

      def initialize(*args)
        super
        _load_db
        @queue = ::GatherQueue.first
        @queue.gather = self
      end

      #listen_to :channel, method: :channel_listen
      #def channel_listen(m)
      #end

      listen_to :part, :quit, :kill, method: :on_leaving
      def on_leaving(m)
        match = get_match_in(m.user)
        if match
          sub = match.remove_player(m.user)
          if sub
            m.channel.msg sub[:msg]
          end
        elsif @queue.has_player?(m.user)
          remove_user_from_queue(m.user)
        end
      end

      #timer KAG::Config.instance[:idle][:check_period], method: :check_for_afk
      #def check_for_afk
      #  KAG::Config.instance[:channels].each do |c|
      #    @queue.check_for_afk(self)
      #  end
      #end


      command :rsub,{user: :string},
        summary: "Request a sub for a match",
        description: "If a player leaves a match early, you can use this command to request a sub for the match"
      def rsub(m,nick)
        unless is_banned?(m.user)
          match = get_match_in(m.user)
          if match
            user = ::User.fetch(nick)
            if user
              match.gather = self
              match.request_sub(user)
            end
          end
        end
      end

      command :sub,{match_id: :integer},
        summary: "Sub yourself into a match that needs subs.",
        description: "If a player leaves a match early, you can use this command to sub in and join the match"
      def sub(m,match_id)
        unless is_banned?(m.user)
          match = ::Match.find(match_id)
          if match
            match.gather = self
            match.sub_in(m.user)
          end
        end
      end

      command :add,{},
        summary: "Add yourself to the active queue for the next match"
      def add(m)
        unless is_banned?(m.user)
          KAG::User::User.add_stat(m.user,:adds)
          KAG::Stats::Main.add_stat(:adds)
          add_user_to_queue(m,m.user)
        end
      end

      command :rem,{},
        summary: "Remove yourself from the active queue for the next match"
      def rem(m)
        unless is_banned?(m.user)
          match = get_match_in(m.user)
          if match
            match.remove_player(m.user)
            send_channels_msg "#{m.user.authname} has left the match at #{match.server.name}! You can sub in by typing !sub"
          elsif @queue.has_player?(m.user)
            KAG::User::User.add_stat(m.user,:rems)
            KAG::Stats::Main.add_stat(:rems)
            unless remove_user_from_queue(m.user)
              debug "#{m.user.authname} is not in the queue."
            end
          end
        end
      end

      command :list,{},
        summary: "List the users signed up for the next match"
      def list(m)
        unless is_banned?(m.user)
          m.user.notice @queue.list_text
        end
      end

      command :status,{},
        summary: "Show the number of ongoing matches"
      def status(m)
        unless is_banned?(m.user)
          reply m,"Matches in progress: #{::Match.total_in_progress.to_s}"
        end
      end

      command :end,{},
        summary: "End the current match",
        description: "End the current match. This will only work if you are in the match. After !end is called by 3 different players, the match will end."
      def end(m)
        unless is_banned?(m.user)
          puts "past is_banned?"
          match = get_match_in(m.user)
          if match
            puts "found match"
            match.add_end_vote
            if match.voted_to_end?
              puts "voted_to_end? past, attempting to cease"
              match.cease(self)
            else
              reply m,"End vote started, #{match.get_needed_end_votes_left} more votes to end match at #{match.server.key}"
            end
          else
            puts "No match found"
          end
        end
      end

      def add_user_to_queue(m,user,send_msg = true)
        if @queue.has_player?(user)
          reply m,"#{user.authname} is already in the queue!"
          false
        else
          match = get_match_in(user)
          if match
            reply m,"#{user.authname} is already in a match!"
            false
          else
            if @queue.add(user)
              send_channels_msg "Added #{user.authname} to queue (#{::Match.type_as_string}) [#{@queue.length}]" if send_msg
              check_for_new_match
              true
            else
              user.send("Failed to add you to queue!")
              false
            end
          end
        end
      end

      def remove_user_from_queue(user,send_msg = true)
        if @queue.remove(user,send_msg)
          true
        else
          puts "User #{user.authname} was not in a queue!"
          false
        end
      end

      def get_match_in(user)
        Match.player_in(user)
      end

      def check_for_new_match
        if @queue.is_full?
          unless @queue.start_match(self)
            send_channels_msg "Could not find any available servers!"
            debug "FAILED TO FIND UNUSED SERVER"
            return false
          end
        end
      end

      def get_unused_server
        KAG::Server.find_unused
      end

      # admin methods

      command :clear,{},
        summary: "Clear (empty) the ongoing queue",
        admin: true
      def clear(m)
        if is_admin(m.user)
          reply m,"Match queue cleared."
          @queue.reset
        end
      end

      command :rem,{nicks: :string},
        summary: "Remove a specific user from the queue",
        method: :rem_admin,
        admin: true
      def rem_admin(m, nicks)
        if is_admin(m.user)
          nicks = nicks.split(",")
          nicks.each do |nick|
            u = User(nick)
            if u
              remove_user_from_queue(u)
            else
              reply m,"Could not find user #{nick}"
            end
          end
        end
      end

      command :rem_silent,{nicks: :string},
        summary: "Remove a specific user from the queue without pinging the user in the channel",
        admin: true
      def rem_silent(m, nicks)
        if is_admin(m.user)
          nicks = nicks.split(",")
          nicks.each do |nick|
            u = User(nick)
            if u
              remove_user_from_queue(u,false)
            else
              reply m,"Could not find user #{nick}"
            end
          end
        end
      end

      command :add,{nicks: :string},
        summary: "Add a specific user to the queue",
        method: :add_admin,
        admin: true
      def add_admin(m, nicks)
        if is_admin(m.user)
          nicks = nicks.split(",")
          nicks.each do |nick|
            u = User(nick)
            if u
              add_user_to_queue(m,u)
            else
              reply m,"Could not find user #{nick}"
            end
          end
        end
      end

      command :add_silent,{nicks: :string},
        summary: "Add a specific user to the queue without pinging the user in the channel",
        admin: true
      def add_silent(m, nicks)
        if is_admin(m.user)
          nicks = nicks.split(",")
          puts nicks.inspect
          nicks.each do |nick|
            u = User(nick)
            if u
              add_user_to_queue(m,u,false)
            else
              reply m,"Could not find user #{nick}"
            end
          end
        end
      end

      command :restart_map,{},
        summary: "Restart the map of the match you are in",
        admin: true
      def restart_map(m)
        if is_admin(m.user)
          match = get_match_in(m.user)
          if match and match.server(true)
            match.server.restart_map
          end
        end
      end

      command :restart_map,{server: :string},
        summary: "Restart the map of a given server",
        method: :restart_map_specify,
        admin: true
      def restart_map_specify(m,server)
        if is_admin(m.user)
          s = ::Server.find_by_name(server)
          if s
            s.restart_map
          else
            m.reply "No server found with key #{server.to_s}"
          end
        end
      end

      command :restart_map,{},
        summary: "Next map the match of the server you are in",
        admin: true
      def next_map(m)
        if is_admin(m.user)
          match = get_match_in(m.user)
          if match and match.server(true)
            match.server.next_map
          end
        end
      end

      command :next_map,{server: :string},
        summary: "Next map a given server",
        method: :next_map_specify,
        admin: true
      def next_map_specify(m,server)
        if is_admin(m.user)
          s = ::Server.find_by_name(server)
          if s
            s.next_map
          else
            m.reply "No server found with key #{server}"
          end
        end
      end

      command :kick_from_match,{nick: :string},
        summary: "Actually kick a user from a match",
        admin: true
      def kick_from_match(m,nick)
        if is_admin(m.user)
          user = User(nick.to_s)
          user.refresh
          if user
            match = get_match_in(user)
            if match
              match.remove_player(user)
              m.reply "#{user.nick} has been kicked from the match"
            else
              m.reply "#{user.nick} is not in a match!"
            end
          else
            reply m,"User #{nick} not found"
          end
        end
      end

      command :quit,{},
        summary: "Quit the bot",
        admin: true
      def quit(m)
        if is_admin(m.user)
          ::Server.all.each do |s|
            if s.listener
              s.listener.async.disconnect
            end
          end
          m.bot.quit("Shutting down...")
        end
      end

      command :restart,{},
        summary: "Restart the bot",
        admin: true
      def restart(m)
        if is_admin(m.user)
          ::Server.all.each do |s|
            s.disconnect
          end

          cmd = (KAG::Config.instance[:restart_method] or "nohup sh gather.sh &")
          debug cmd
          pid = spawn cmd
          debug "Restarting bot, new process ID is #{pid.to_s} ..."
          if m.bot
            m.bot.quit "Restarting! Back in a second!"
          end
          sleep(0.5)
          exit
        end
      end
    end
  end
end