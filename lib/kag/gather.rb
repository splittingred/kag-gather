require 'cinch'
require File.dirname(__FILE__)+'/bot'
require File.dirname(__FILE__)+'/config'
require File.dirname(__FILE__)+'/server'

module KAG
  class Gather
    include Cinch::Plugin

    def config
      KAG::Config.instance
    end

    attr_accessor :queue

    def initialize(*args)
      super
      @queue = {}
      @matches = {}
    end

    #listen_to :channel, method: :channel_listen
    #def channel_listen(m)
    #end

    listen_to :leaving, method: :on_leaving
    def on_leaving(m,user)
      remove_user_from_queue(user) if @queue.key?(user)
      remove_user_from_match(user) if in_match(user)
    end

    listen_to :nick, method: :on_nick
    def on_nick(m)
      if @queue.key?(m.user.last_nick)
        @queue[m.user.nick] = @queue[m.user.last_nick]
        @queue.delete(m.user.last_nick)
      elsif in_match(m.user.last_nick)
        @matches.each do |m|
          i = m[:team1].index(m.user.last_nick)
          if i != nil
            m[:team1].delete_at(i)
            m[:team1] << m.user.nick
          end
          i = m[:team2].index(m.user.last_nick)
          if i != nil
            m[:team2].delete_at(i)
            m[:team2] << m.user.nick
          end
        end
      end
    end

    match "add", method: :evt_add
    def evt_add(m)
      unless @queue.key?(m.user.nick) or in_match(m.user.nick)
        @queue[m.user.nick] = SymbolTable.new({
            :user => m.user,
            :channel => m.channel,
            :message => m.message,
            :joined_at => Time.now
        })
        send_channels_msg "Added #{m.user.nick} to queue (#{get_match_type_as_string}) [#{@queue.length}]"
        check_for_new_match(m)
      end
    end

    match "rem", method: :evt_rem
    def evt_rem(m)
      remove_user_from_match(m.user.nick)
      remove_user_from_queue(m.user.nick)
    end

    match "list", method: :evt_list
    def evt_list(m)
      users = []
      @queue.each do |n,u|
        users << n
      end
      m.user.send "Queue (#{get_match_type_as_string}) [#{@queue.length}] #{users.join(", ")}"
    end

    match "status", method: :evt_status
    def evt_status(m)
      m.reply "Matches in progress: #{@matches.length.to_s}"
    end

    match "end", method: :evt_end
    def evt_end(m)
      @matches.each do |k,match|
        info = match[:server].info
        if info
          players_on = info[:serverStatus][:playerList].length
          if players_on > 0
            m.reply "Cannot end a match for #{match[:server][:key]} in progress, there are #{players_on.to_s} players still playing!"
          else
            @matches.delete(k)
            send_channels_msg("Match at #{match[:server][:key]} finished!")
          end
        end
      end
    end

    def remove_user_from_queue(nick)
      if @queue.key?(nick)
        @queue.delete(nick)
        send_channels_msg "Removed #{nick} from queue (#{get_match_type_as_string}) [#{@queue.length}]"
      end
    end

    def remove_user_from_match(nick)
      match = get_match_in(nick)
      if match
        send_channels_msg "#{user} has left the match at #{match[:key]}! Find a sub!"
      end
    end

    def in_match(nick)
      get_match_in(nick)
    end

    def get_match_in(nick)
      m = false
      @matches.each do |k,match|
        if match[:team1] and match[:team1].include?(nick)
          m = match
        elsif match[:team2] and match[:team2].include?(nick)
          m = match
        end
      end
      m
    end

    def get_match_type_as_string
      ms = KAG::Config.instance[:match_size]
      ts = (ms / 2).ceil
      "#{ts.to_s}v#{ts.to_s} #{KAG::Config.instance[:match_type]}"
    end

    def check_for_new_match(m)
      if @queue.length >= KAG::Config.instance[:match_size]
        playing = []
        @queue.each do |n,i|
          playing << n
        end

        server = get_unused_server
        unless server
          send_channels_msg "Could not find any available servers!"
          debug "FAILED TO FIND UNUSED SERVER"
          return false
        end

        @queue = {}
        playing.shuffle!
        match_size = KAG::Config.instance[:match_size].to_i
        match_size = 2 if match_size < 2

        lb = (match_size / 2).ceil.to_i
        lb = 1 if lb < 1

        debug "MATCH SIZE #{match_size.to_s}"
        debug "LOWER BOUND: #{lb.to_s}"
        debug "PLAYERS: #{playing.join(",")}"

        team1 = playing.slice(0,lb)
        team2 = playing.slice(lb,match_size)

        send_channels_msg("MATCH: #{get_match_type_as_string} - #{team1.join(", ")} (Blue) vs #{team2.join(", ")} (Red)")
        msg = "Join #{server[:key]} - #{server[:ip]}:#{server[:port]} password #{server[:password]} | Visit kag://#{server[:ip]}/#{server[:password]} | "
        team1.each do |p|
          User(p).send(msg+" Blue Team #{team1.join(", ")}") unless p.include?("player")
        end
        team2.each do |p|
          User(p).send(msg+" Red Team #{team2.join(", ")}") unless p.include?("player")
        end

        @matches[server[:key]] = {
            :team1 => team1,
            :team2 => team2,
            :server => server
        }
      end
    end

    def send_channels_msg(msg)
      KAG::Config.instance[:channels].each do |c|
        Channel(c).send(msg)
      end
    end

    def get_unused_server
      used_servers = []
      @matches.each do |k,m|
        used_servers << k
      end
      available_servers = KAG::Config.instance[:servers]
      available_servers.each do |k,s|
        unless used_servers.include?(k)
          s[:key] = k
          return KAG::Server.new(s)
        end
      end
      false
    end

    match "help", method: :evt_help
    def evt_help(m)
      msg = "Commands: !add, !rem, !list, !status, !help, !end"
      msg = msg + ", !rem [nick], !clear, !quit" if is_admin(m.user)
      User(m.user.nick).send(msg)
    end

    # admin methods

    def debug(msg)
      if KAG::Config.instance[:debug]
        puts msg
      end
    end

    def is_admin(user)
      user.refresh
      o = (KAG::Config.instance[:owners] or [])
      o.include?(user.authname)
    end

    match "clear", method: :evt_clear
    def evt_clear(m)
      if is_admin(m.user)
        send_channels_msg "Match queue cleared."
        @queue = {}
      end
    end

    match /rem (.+)/, method: :evt_rem_admin
    def evt_rem_admin(m, arg)
      if is_admin(m.user)
        remove_user_from_queue(arg)
      end
    end

    match "quit", method: :evt_quit
    def evt_quit(m)
      if is_admin(m.user)
        m.bot.quit("Shutting down...")
      end
    end

  end
end