require 'cinch'
require 'kag/common'
require 'kag/bot/bot'
require 'kag/bans/report'
require 'kag/server'
require 'kag/match'

module KAG
  module Gather
    class Plugin
      include Cinch::Plugin
      include KAG::Common

      attr_accessor :queue,:servers

      def initialize(*args)
        super
        @queue = {}
        @matches = {}
        _load_servers
      end

      def _load_servers
        @servers = {}
        KAG::Config.instance[:servers].each do |k,s|
          s[:key] = k
          @servers[k] = KAG::Server.new(s)
        end
      end

      #listen_to :channel, method: :channel_listen
      #def channel_listen(m)
      #end

      listen_to :leaving, :method => :on_leaving
      def on_leaving(m,nick)
        unless is_banned?(m.user)
          nick = nick.to_s
          match = get_match_in(nick)
          if match
            sub = match.remove_player(nick)
            if sub
              m.channel.msg sub[:msg]
            end
          elsif @queue.key?(nick)
            remove_user_from_queue(nick)
          end
        end
      end

      listen_to :nick, :method => :on_nick
      def on_nick(m)
        unless is_banned?(m.user)
          match = get_match_in(m.user.last_nick)
          if match
            match.rename_player(m.user.last_nick,m.user.nick)
          elsif @queue.key?(m.user.last_nick)
            @queue[m.user.nick] = @queue[m.user.last_nick]
            @queue.delete(m.user.last_nick)
          end
        end
      end

      match "sub", :method => :evt_sub
      def evt_sub(m)
        unless is_banned?(m.user)
          @matches.each do |k,match|
            if match.needs_sub?
              placement = match.sub_in(m.user.nick)
              if placement
                reply m,placement[:channel_msg]
                User(m.user.nick).send placement[:private_msg]
              end
            end
          end
        end
      end

      match "add", :method => :evt_add
      def evt_add(m)
        unless is_banned?(m.user)
          add_user_to_queue(m,m.user.nick)
        end
      end

      match "rem", method: :evt_rem
      def evt_rem(m)
        unless is_banned?(m.user)
          match = get_match_in(m.user.nick)
          if match
            match.remove_player(m.user.nick)
            send_channels_msg "#{m.user.nick} has left the match at #{match.server[:key]}! You can sub in by typing !sub"
          elsif @queue.key?(m.user.nick)
            unless remove_user_from_queue(m.user.nick)
              debug "#{nick} is not in the queue."
            end
          end
        end
      end

      match "list", :method => :evt_list
      def evt_list(m)
        unless is_banned?(m.user)
          users = []
          @queue.each do |n,u|
            users << n
          end
          m.user.send "Queue (#{KAG::Match.type_as_string}) [#{@queue.length}] #{users.join(", ")}"
        end
      end

      match "status", :method => :evt_status
      def evt_status(m)
        unless is_banned?(m.user)
          reply m,"Matches in progress: #{@matches.length.to_s}"
        end
      end

      match "end", :method => :evt_end
      def evt_end(m)
        unless is_banned?(m.user)
          match = get_match_in(m.user.nick)
          if match
            match.add_end_vote
            if match.voted_to_end?
              match.cease
              @matches.delete(match.server[:key])
              send_channels_msg("Match at #{match.server[:key]} finished!")
            else
              reply m,"End vote started, #{match.get_needed_end_votes_left} more votes to end match at #{match.server[:key]}"
            end
          else
            reply m,"You're not in a match, silly! Stop trying to hack me."
          end
        end
      end

      def add_user_to_queue(m,nick,send_msg = true)
        if @queue.key?(nick)
          reply m,"#{nick} is already in the queue!"
        elsif get_match_in(nick)
          reply m,"#{nick} is already in a match!"
        else
          @queue[nick] = SymbolTable.new({
              :user => User(nick),
              :irc => m.channel,
              :message => m.message,
              :joined_at => Time.now
          })
          send_channels_msg "Added #{nick} to queue (#{KAG::Match.type_as_string}) [#{@queue.length}]" if send_msg
          check_for_new_match
        end
      end

      def remove_user_from_queue(nick,send_msg = true)
        if @queue.key?(nick)
          @queue.delete(nick)
          send_channels_msg "Removed #{nick} from queue (#{KAG::Match.type_as_string}) [#{@queue.length}]" if send_msg
          true
        else
          false
        end
      end

      def get_match_in(nick)
        m = false
        @matches.each do |k,match|
          if match.has_player?(nick)
            m = match
          end
        end
        m
      end

      def check_for_new_match
        if @queue.length >= KAG::Config.instance[:match_size]
          players = []
          @queue.each do |n,i|
            players << n
          end

          server = get_unused_server
          unless server
            send_channels_msg "Could not find any available servers!"
            debug "FAILED TO FIND UNUSED SERVER"
            return false
          end

          # reset queue first to prevent 11-player load
          @queue = {}

          match = KAG::Match.new(SymbolTable.new({
            :server => server,
            :players => players
          }))
          match.start # prepare match data
          messages = match.notify_teams_of_match_start # gather texts for private messages
          send_channels_msg(match.text_for_match_start,false) # send channel-wide first
          messages.each do |nick,msg|
            User(nick.to_s).send(msg) unless nick.to_s.include?("player")
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

      match "clear", :method => :evt_clear
      def evt_clear(m)
        if is_admin(m.user)
          send_channels_msg "Match queue cleared."
          @queue = {}
        end
      end

      match /rem (.+)/, :method => :evt_rem_admin
      def evt_rem_admin(m, arg)
        if is_admin(m.user)
          arg = arg.split(" ")
          arg.each do |nick|
            remove_user_from_queue(nick)
          end
        end
      end

      match /rem_silent (.+)/, :method => :evt_rem_silent_admin
      def evt_rem_silent_admin(m, arg)
        if is_admin(m.user)
          arg = arg.split(" ")
          arg.each do |nick|
            remove_user_from_queue(nick,false)
          end
        end
      end

      match /add (.+)/, :method => :evt_add_admin
      def evt_add_admin(m, arg)
        if is_admin(m.user)
          arg = arg.split(" ")
          arg.each do |nick|
            add_user_to_queue(m,nick)
          end
        end
      end

      match /add_silent (.+)/, :method => :evt_add_silent_admin
      def evt_add_silent_admin(m, arg)
        if is_admin(m.user)
          arg = arg.split(" ")
          arg.each do |nick|
            add_user_to_queue(m,nick,false)
          end
        end
      end

      match "restart_map", :method => :evt_restart_map
      def evt_restart_map(m)
        if is_admin(m.user)
          match = get_match_in(m.user.nick)
          if match and match.server
            match.server.restart_map
          end
        end
      end

      match /restart_map (.+)/, :method => :evt_restart_map_specify
      def evt_restart_map_specify(m,arg)
        if is_admin(m.user)
          if @servers[key]
            @servers[key].restart_map
          else
            m.reply "No server found with key #{arg}"
          end
        end
      end

      match "next_map", :method => :evt_next_map
      def evt_next_map(m)
        if is_admin(m.user)
          match = get_match_in(m.user.nick)
          if match and match.server
            match.server.next_map
          end
        end
      end

      match /next_map (.+)/, :method => :evt_next_map_specify
      def evt_next_map_specify(m,arg)
        if is_admin(m.user)
          if @servers[key]
            @servers[key].next_map
          else
            m.reply "No server found with key #{arg}"
          end
        end
      end

      match /kick_from_match (.+)/, :method => :evt_kick_from_match
      def evt_kick_from_match(m,nick)
        if is_admin(m.user)
          match = get_match_in(nick)
          if match
            match.remove_player(nick)
            m.reply "#{nick} has been kicked from the match"
          else
            m.reply "#{nick} is not in a match!"
          end
        end
      end
    end
  end
end