require 'symboltable'
require 'json'

module KAG
  module User
    class User < SymbolTable

      def initialize(user)
        self[:authname] = user.authname
        super({})
        self.merge!(_load)
      end

      def reload
        puts "Reloading data file..."
        self.merge!(self._load)
      end

      # Sets the value of the given +key+ to +val+.
      def store(key, val)
        super(key,val)
        self.save
      end

      def save
        File.open("data/user/#{self.authname}.json","w") do |f|
          f.write(self.to_json)
        end
      end

      def linked?
        self.key?(:kag_user) and !self[:kag_user].to_s.empty?
      end

      def add_stat(stat,increment = 1)
        stat = stat.to_sym
        self[stat] = 0 unless self[stat]
        self[stat] = self[stat].to_i + increment.to_i
        self.save
      end

      def subtract_stat(stat,decrement = 1)
        stat = stat.to_sym
        if self[stat]
          self[stat] = self[stat].to_i - decrement.to_i
        else
          self[stat] = 0
        end
        self.save
      end

      def self.add_stat(user,stat,increment = 1)
        u = KAG::User::User.new(user)
        u.add_stat(stat,increment)
      end

      def self.subtract_stat(user,stat,decrement = 1)
        u = KAG::User::User.new(user)
        u.subtract_stat(stat,decrement)
      end

      def self.stats(user)
        u = KAG::User::User.new(user)
        "#{user.nick} has played in #{u.matches.to_i} matches, has added #{u.adds.to_i} times, subbed #{u.substitutions.to_i} times, and has deserted matches #{u.desertions.to_i} times."
      end

      protected

      def _load
        return {} unless self[:authname]

        unless File.exists?("data/user/#{self[:authname]}.json")
          File.open("data/user/#{self[:authname]}.json","w") {|f| f.write("{}") }
        end

        f = ::IO.read("data/user/#{self[:authname]}.json")
        if f and !f.empty?
          SymbolTable.new(JSON.parse(f))
        else
          SymbolTable.new
        end
      end
    end
  end
end