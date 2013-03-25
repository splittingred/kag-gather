module KAG
  module Gather
    class Queue

      attr_accessor :players

      def initialize
        self.players = {}
      end

      def add(user)
        return false unless user.authname and !user.authname.to_s.empty?
        self.players[user.authname.to_sym] = user
        true
      end

      def remove(user)
        return false unless user.authname and !user.authname.to_s.empty?
        if has_player?(user)
          self.players.delete(user.authname.to_sym)
          true
        else
          false
        end
      end

      def list
        m = []
        self.players.each do |authname,user|
          m << user.authname
        end
        m.join(", ")
      end

      def has_player?(user)
        return false unless user.authname and !user.authname.to_s.empty?
        self.players.has_key?(user.authname.to_sym)
      end

      def length
        self.players.length
      end

      def reset
        self.players = {}
      end
    end
  end
end