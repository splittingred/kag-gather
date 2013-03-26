require 'cinch'
require 'kag/common'
require 'commands/help'
require 'kag/bot/bot'
require 'kag/bans/report'
require 'kag/server/instance'
require 'kag/gather/queue'
require 'kag/gather/match'

module KAG
  module Gather
    class Plugin
      include Cinch::Plugin
      include Cinch::Commands
      include KAG::Common

      attr_accessor :queue,:servers

      def initialize(*args)
        super
        @queue = KAG::Gather::Queue.new
        @matches = {}
        _load_servers
      end

      def _load_servers
        @servers = KAG::Server::Instance.fetch_all
      end

      #listen_to :channel, method: :channel_listen
      #def channel_listen(m)
      #end

      listen_to :leaving, :method => :on_leaving
      def on_leaving(m,user)
        match = get_match_in(user)
        if match
          sub = match.remove_player(user)
          if sub
            m.channel.msg sub[:msg]
          end
        elsif @queue.has_player?(user)
          remove_user_from_queue(user)
        end
      end

      listen_to :nick, :method => :on_nick
      def on_nick(m)
      end

      timer KAG::Config.instance[:idle][:check_period], method: :check_for_afk
      def check_for_afk
        KAG::Config.instance[:channels].each do |c|
          @queue.check_for_afk(self)
        end
      end


      command :sub,{},
        summary: "Sub into a match",
        description: "If a player leaves a match early, you can use this command to sub in and join the match"
      def sub(m)
        unless is_banned?(m.user)
          @matches.each do |k,match|
            if match.needs_sub?
              placement = match.sub_in(m.user)
              if placement
                placement[:channel_msg] = placement[:channel_msg].gsub("[[+user]]",m.user.authname)
                reply m,placement[:channel_msg]
                m.user.send placement[:private_msg]
              end
            end
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
            send_channels_msg "#{m.user.authname} has left the match at #{match.server[:key]}! You can sub in by typing !sub"
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
          m.user.send "Queue (#{KAG::Gather::Match.type_as_string}) [#{@queue.length}] #{@queue.list}"
        end
      end

      command :status,{},
        summary: "Show the number of ongoing matches"
      def status(m)
        unless is_banned?(m.user)
          reply m,"Matches in progress: #{@matches.length.to_s}"
        end
      end

      command :end,{},
        summary: "End the current match",
        description: "End the current match. This will only work if you are in the match. After !end is called by 3 different players, the match will end."
      def end(m)
        unless is_banned?(m.user)
          match = get_match_in(m.user)
          if match
            match.add_end_vote
            if match.voted_to_end?
              match.cease
              @matches.delete(match.server[:key])
              send_channels_msg("Match at #{match.server[:key]} finished!")
            else
              reply m,"End vote started, #{match.get_needed_end_votes_left} more votes to end match at #{match.server[:key]}"
            end
          end
        end
      end

      def add_user_to_queue(m,user,send_msg = true)
        if @queue.has_player?(user)
          reply m,"#{user.authname} is already in the queue!"
          false
        elsif get_match_in(user)
          reply m,"#{user.authname} is already in a match!"
          false
        else
          if @queue.add(user)
            send_channels_msg "Added #{user.authname} to queue (#{KAG::Gather::Match.type_as_string}) [#{@queue.length}]" if send_msg
            check_for_new_match
            true
          else
            false
          end
        end
      end

      def remove_user_from_queue(user,send_msg = true)
        if @queue.has_player?(user)
          if @queue.remove(user)
            send_channels_msg "Removed #{user.authname} from queue (#{KAG::Gather::Match.type_as_string}) [#{@queue.length}]" if send_msg
            true
          else
            false
          end
        else
          false
        end
      end

      def get_match_in(user)
        m = false
        @matches.each do |k,match|
          if match.has_player?(user)
            m = match
          end
        end
        m
      end

      def check_for_new_match
        if @queue.length >= KAG::Config.instance[:match_size]
          server = get_unused_server
          unless server
            send_channels_msg "Could not find any available servers!"
            debug "FAILED TO FIND UNUSED SERVER"
            return false
          end

          players = @queue.players

          # reset queue first to prevent 11-player load
          @queue.reset

          match = KAG::Gather::Match.new(SymbolTable.new({
            :server => server,
            :players => players,
            :bot => self.bot
          }))
          match.start # prepare match data
          messages = match.notify_teams_of_match_start # gather texts for private messages
          send_channels_msg(match.text_for_match_start,false) # send channel-wide first
          messages.each do |user,msg|
            user.send(msg)
            sleep(2) # prevent excess flood stuff
          end
          @matches[server[:key]] = match
        end
      end

      def get_unused_server
        server = false
        @servers.shuffle!
        @servers.each do |k,s|
          server = s unless s.in_use?
        end
        server
      end

      # admin methods

      command :clear,{},
        summary: "Clear (empty) the ongoing queue",
        admin: true
      def clear(m)
        if is_admin(m.user)
          send_channels_msg "Match queue cleared."
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
          if match and match.server
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
          if @servers[server.to_sym]
            @servers[server.to_sym].restart_map
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
          if match and match.server
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
          if @servers[server]
            @servers[server].next_map
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
    end
  end
end