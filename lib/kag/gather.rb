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

    listen_to :channel, method: :channel_listen
    def channel_listen(m)

    end

    listen_to :leaving, method: :leaving
    def leaving(m)
      if @queue.key?(m.user.nick)
        remove_from_queue(m)
      end
    end

    listen_to :nick, method: :handle_nick_change
    def handle_nick_change(m)
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

    match "add", method: :add_to_queue
    def add_to_queue(m)
      unless @queue.key?(m.user.nick) or in_match(m.user.nick)
        @queue[m.user.nick] = SymbolTable.new({
            :user => m.user,
            :channel => m.channel,
            :message => m.message,
            :joined_at => Time.now
        })
        send_channels_msg "Added #{m.user.nick} to queue (5v5 CTF) [#{@queue.length}]"
        check_for_new_match(m)
      end
    end

    match "rem", method: :remove_from_queue
    def remove_from_queue(m)
      if @queue.key?(m.user.nick)
        @queue.delete(m.user.nick)
        send_channels_msg "Removed #{m.user.nick} from queue (5v5 CTF) [#{@queue.length}]"
      end
    end

    match "list", method: :list_queue
    def list_queue(m)
      users = []
      @queue.each do |n,u|
        users << n
      end
      m.user.send "Queue (5v5 CTF) [#{@queue.length}] #{users.join(", ")}"
    end

    match "status", method: :status
    def status(m)
      m.reply "Matches in progress: #{@matches.length.to_s}"
    end

    match "end", method: :end_match
    def end_match(m)
      @matches.each do |k,match|
        info = match[:server].info
        if info
          players_on = info[:serverStatus][:playerList].length
          if players_on > 0
            m.reply "Cannot end a match for #{match[:server][:ip]} in progress, there are #{players_on.to_s} players still playing!"
          else
            @matches.shift
            send_channels_msg("Match at #{match[:server][:ip]} finished!")
          end
        end
      end
    end

    def in_match(nick)
      playing = false
      @matches.each do |m|
        playing = true if (m[:team1].include?(nick) or m[:team2].include?(nick))
      end
      playing
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

        lb = (match_size / 2).ceil.to_i - 1
        lb = 1 if lb < 1

        (match_size-1).times { |x| playing << "player#{(x+1).to_s}" } if KAG::Config.instance[:debug]

        debug "MATCH SIZE #{match_size.to_s}"
        debug "LOWER BOUND: #{lb.to_s}"
        debug "PLAYERS: #{playing.join(",")}"

        team1 = playing.slice(0,lb)
        team2 = playing.slice(lb,match_size)

        send_channels_msg("MATCH: #{team1.join(", ")} (Blue) vs #{team2.join(", ")} (Red)")
        msg = "Join \x0307#{server[:ip]}:#{server[:port]} password #{server[:password]} \x0310| Visit \x0307kag://#{server[:ip]}/#{server[:password]} \x0310| "
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

    match "quit", method: :quit
    def quit(m)
      if is_admin(m.user)
        m.bot.quit("Shutting down...")
      end
    end

  end
end