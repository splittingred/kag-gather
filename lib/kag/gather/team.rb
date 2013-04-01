require 'cinch'
require 'cinch/user'
require 'symboltable'
require 'kag/config'
require 'kag/user/user'

module KAG
  module Gather
    class Team < SymbolTable

      def setup
        setup_classes
        self
      end

      def setup_classes
        classes = KAG::Config.instance[:classes].clone
        classes.shuffle!

        self.teammates = {}
        self.players.each do |authname,user|
          self.teammates[authname.to_sym] = classes.shift
        end
        self
      end

      def notify_of_match_start(gather)
        puts "start of team.notify_of_match_start"
        msg = "Join \x0305#{self.match.server.key} - #{self.match.server.ip}:#{self.match.server.port} \x0306password #{self.match.server.password}\x0301 | Visit kag://#{self.match.server.ip}/#{self.match.server.password} | "
        msg = msg + " \x0303Class: " if KAG::Config.instance[:pick_classes]

        puts "after message compile in team.notify_of_match_start"

        self.players.each do |authname,user|
          player_msg = msg.clone
          player_msg = player_msg+cls if KAG::Config.instance[:pick_classes] and cls and !cls.empty?
          player_msg = player_msg+" #{self[:color]}#{self[:name]} with: #{self.teammates.keys.join(", ")}"
          user.send(player_msg)
          sleep(2) # prevent excess flood stuff
        end
      end

      def text_for_match_start
        "#{self[:color]}#{self.players.keys.join(", ")} (#{self[:name]})"
      end

      def has_player?(user)
        if user.authname
          self.players.keys.include?(user.authname.to_sym)
        else
          false
        end
      end

      def remove_player(user)
        if has_player?(user)
          sub = {}
          sub[:cls] = self.teammates[user.authname.to_sym]
          sub[:team] = self.clone
          sub[:msg] = "Sub needed at #{self.match.server[:ip]} for #{sub[:team][:name]}, #{sub[:cls]} Class! Type !sub to claim it!"
          sub[:channel_msg] = "[[+user]] is now subbing in for #{self[:name]} at #{self.match.server[:key]}. Subs still needed: #{self.match[:subs_needed].length}"
          sub[:private_msg] = "Please #{self.match.server.text_join} | #{sub[:cls]} on the #{self[:name]} Team"
          self.players.delete(user.authname.to_sym)
          self.teammates.delete(user.authname.to_sym)

          KAG::User::User.subtract_stat(user,:matches)
          KAG::User::User.add_stat(user,:desertions)

          if self.match and self.match.server
            self.match.server.kick(user.nick)
          end

          sub
        else
          false
        end
      end

      def kick_all
        self.players.each do |authname,user|
          self.match.server.kick(user.nick.to_s)
        end
      end
    end
  end
end