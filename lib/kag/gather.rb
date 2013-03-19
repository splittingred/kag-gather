require 'cinch'
require File.dirname(__FILE__)+'/bot'
require File.dirname(__FILE__)+'/config'

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
      @matches = []
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
        m.reply "Added #{m.user.nick} to queue (5v5 CTF) [#{@queue.length}]"
        check_for_new_match(m)
      end
    end

    def in_match(nick)
      playing = false
      @matches.each do |m|
        playing = true if (m[:team1].include?(nick) or m[:team2].include?(nick))
      end
      playing
    end

    match "rem", method: :remove_from_queue
    def remove_from_queue(m)
      if @queue.key?(m.user.nick)
        @queue.delete(m.user.nick)
        m.reply "Removed #{m.user.nick} from queue (5v5 CTF) [#{@queue.length}]"
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
      @matches.shift
      m.reply "Match finished!"
    end

    def check_for_new_match(m)
      if @queue.length > KAG::Config.instance[:match_size]
        playing = []
        @queue.each do |n,i|
          playing << n
        end

        9.times { |x| playing << "player#{(x+1).to_s}" } if KAG::Config.instance[:debug]

        @queue = {}
        playing.shuffle!
        team1 = playing.slice(0..4)
        team2 = playing.slice(5..9)
        m.reply("MATCH: #{team1.join(", ")} (Blue) vs #{team2.join(", ")} (Red)")

        server = get_unused_server
        return false unless server

        msg = "Join \x0307#{server} \x0310| Visit \x0307kag://#{server}/ \x0310| "
        team1.each do |p|
          User(p).send(msg+" - Blue Team #{team1.join(", ")}") unless p.include?("player")
        end
        team2.each do |p|
          User(p).send(msg+" - Red Team #{team2.join(", ")}") unless p.include?("player")
        end

        @matches << {
            :team1 => team1,
            :team2 => team2,
            :server => {}
        }
      end
    end

    def get_unused_server
      used_servers = []
      @matches.each do |m|
        used_servers << m[:server]
      end
      available_servers = KAG::Config.instance[:servers]
      available_servers.each do |s|
        return s unless used_servers.include?(s)
      end
      false
    end

    # admin methods

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