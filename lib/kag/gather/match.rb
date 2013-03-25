require 'cinch'
require 'cinch/helpers'
require 'symboltable'
require 'kag/config'
require 'kag/gather/team'
require 'kag/user/user'

module KAG
  module Gather
    class Match < SymbolTable
      include Cinch::Helpers

      def self.type_as_string
        ms = KAG::Config.instance[:match_size].to_i
        ts = (ms / 2).ceil
        "#{ts.to_s}v#{ts.to_s} #{KAG::Config.instance[:match_type]}"
      end

      def setup_teams
        self[:players].shuffle!
        match_size = KAG::Config.instance[:match_size].to_i
        match_size = 2 if match_size < 2

        lb = (match_size / 2).ceil.to_i
        lb = 1 if lb < 1

        debug "MATCH SIZE #{match_size.to_s}"
        debug "LOWER BOUND: #{lb.to_s}"
        debug "PLAYERS: #{self[:players].join(",")}"

        self[:players].each do |player|
          u = User(player.to_s)
          if u
            KAG::User::User.add_match(u)
          end
        end

        self[:teams] = []
        self[:teams] << KAG::Gather::Team.new({
          :players => self[:players].slice(0,lb),
          :match => self,
          :color => "\x0312",
          :name => "Blue"
        }).setup
        self[:teams] << KAG::Gather::Team.new({
          :players => self[:players].slice(lb,match_size),
          :match => self,
          :color => "\x0304",
          :name => "Red"
        }).setup
        self[:teams]
      end

      def start
        self[:end_votes] = 0 unless self[:end_votes]
        self[:subs_needed] = []
        setup_teams
        restart_map
      end

      def text_for_match_start
        msg = "MATCH: #{KAG::Gather::Match.type_as_string} - "
        self[:teams].each do |team|
          msg = msg+" "+team.text_for_match_start
        end
        msg+" \x0301(!end when done)"
      end

      def notify_teams_of_match_start
        messages = {}
        self[:teams].each do |t|
          ms = t.notify_of_match_start
          ms.each do |nick,msg|
            messages[nick] = msg
          end
        end
        messages
      end

      def add_end_vote
        self[:end_votes] = 0 unless self[:end_votes] > 0
        self[:end_votes] = self[:end_votes] + 1
      end

      def voted_to_end?
        evt = KAG::Config.instance[:end_vote_threshold].to_i
        evt = 3 if evt < 1
        self[:end_votes] >= evt
      end

      def get_needed_end_votes_left
        evt = KAG::Config.instance[:end_vote_threshold].to_i
        evt - self[:end_votes]
      end

      def has_player?(user)
        playing = false
        self[:teams].each do |team|
          playing = true if team.has_player?(user)
        end
        playing
      end

      def cease
        if self.server
          if self.server.has_rcon?
            self[:teams].each do |team|
              team.kick_all
            end
          else
            debug "NO RCON, so could not kick!"
          end
          self.server.disconnect
          self.server.delete(:match)
          true
        else
          debug "No server for match defined!"
          false
        end
      end

      def restart_map
        if self.server.has_rcon?
          self.server.restart_map
        else
          debug "Cannot restart map, no RCON defined"
        end
      end

      def remove_player(user)
        sub = false
        self[:teams].each do |team|
          if team.has_player?(user)
            sub = team.remove_player(user)
          end
        end
        if sub
          self[:subs_needed] << sub
        end
        sub
      end

      def needs_sub?
        self[:subs_needed].length > 0
      end

      def sub_in(nick)
        placement = false
        if needs_sub?
          placement = self[:subs_needed].shift
        end
        placement
      end

      def rename_player(user)
        self[:teams].each do |team|
          if team.has_player?(user)
            team.rename_player(user)
          end
        end
      end

      def debug(msg)
        if KAG::Config.instance[:debug]
          puts msg
        end
      end
    end
  end
end