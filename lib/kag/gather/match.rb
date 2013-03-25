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
        self.players.shuffle!
        match_size = KAG::Config.instance[:match_size].to_i
        match_size = 2 if match_size < 2

        team_list = [{
          :color => "\x0312",
          :name => "Blue"
        },{
           :color => "\x0304",
           :name => "Red"
        }]
        players_per_team = (match_size / 2).floor.to_i

        debug "MATCH SIZE #{match_size.to_s}"
        debug "Players Per Team: #{players_per_team.to_s}"
        debug "PLAYERS: #{self.players.keys.join(",")}"

        self.players.each do |authname,user|
          KAG::User::User.add_stat(user,:matches)
        end

        self.teams = []
        lb = 0
        team_list.each do |ts|
          eb = lb+players_per_team-1
          eb = self.players.length if eb > self.players.length-1
          debug "Spread: #{lb}..#{(eb)}"
          ps = Hash[self.players.sort_by{|k,v| v.to_s }[lb..(eb)]]
          lb = players_per_team

          self.teams << KAG::Gather::Team.new({
            :players => ps,
            :match => self,
            :color => ts[:color],
            :name => ts[:name]
          }).setup
        end
        self.teams
      end

      def start
        self[:end_votes] = 0 unless self[:end_votes]
        self[:subs_needed] = []
        setup_teams
        restart_map
      end

      def text_for_match_start
        msg = "MATCH: #{KAG::Gather::Match.type_as_string} - "
        self.teams.each do |team|
          msg = msg+" "+team.text_for_match_start
        end
        msg+" \x0301(!end when done)"
      end

      def notify_teams_of_match_start
        messages = {}
        self.teams.each do |t|
          messages.merge!(t.notify_of_match_start)
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
        self.teams.each do |team|
          playing = true if team.has_player?(user)
        end
        playing
      end

      def cease
        if self.server
          if self.server.has_rcon?
            self.teams.each do |team|
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

      def sub_in(user)
        placement = false
        if needs_sub?
          placement = self[:subs_needed].shift
          KAG::User::User.add_stat(user,:substitutions)
        end
        placement
      end

      def debug(msg)
        if KAG::Config.instance[:debug]
          puts msg
        end
      end
    end
  end
end