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
        players = self[:players].clone
        self[:players] = {}
        players.each do |p|
          self[:players][p.to_sym] = classes.shift
        end
        self
      end

      def notify_of_match_start
        server = self.match.server
        msg = "Join \x0305#{server[:key]} - #{server[:ip]}:#{server[:port]} \x0306password #{server[:password]}\x0301 | Visit kag://#{server[:ip]}/#{server[:password]} | "
        msg = msg + " \x0303Class: " if KAG::Config.instance[:pick_classes]

        messages = {}
        self[:players].each do |nick,cls|
          player_msg = msg.clone
          player_msg = player_msg+cls if KAG::Config.instance[:pick_classes] and cls and !cls.empty?
          player_msg = player_msg+" #{self[:color]}#{self[:name]} with: #{self[:players].keys.join(", ")}"
          messages[nick] = player_msg
        end
        messages
      end

      def text_for_match_start
        "#{self[:color]}#{self[:players].keys.join(", ")} (#{self[:name]})"
      end

      def has_player?(user)
        self[:players].keys.include?(user.nick.to_sym)
      end

      def rename_player(user)
        if self[:players].keys.include?(user.last_nick.to_sym)
          cls = self[:players][user.last_nick.to_sym]
          self[:players].delete(user.last_nick.to_sym)
          self[:players][user.nick.to_sym] = cls
        end
      end

      def remove_player(user)
        if has_player?(user)
          sub = {}
          sub[:cls] = self[:players][user.nick]
          sub[:team] = self.clone
          sub[:msg] = "Sub needed at #{self.match.server[:ip]} for #{sub[:team][:name]}, #{sub[:cls]} Class! Type !sub to claim it!"
          sub[:channel_msg] = "#{user.nick} is now subbing in for #{self[:name]} at #{self.match.server[:key]}. Subs still needed: #{self.match[:subs_needed].length}"
          sub[:private_msg] = "Please #{self.match.server.text_join} | #{sub[:cls]} on the #{self[:name]} Team"
          self[:players].delete(user.nick)

          KAG::User::User.subtract_stat(user,:matches)
          KAG::User::User.add_stat(m.user,:desertions)

          if self.match and self.match.server
            self.match.server.kick(user.nick)
          end

          sub
        else
          false
        end
      end

      def kick_all
        self[:players].each do |nick,cls|
          self.match.server.kick(nick.to_s)
        end
      end
    end
  end
end