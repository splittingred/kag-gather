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
        File.open("data/#{self.authname}.json","w") do |f|
          f.write(self.to_json)
        end
      end

      def self.add_match(user)
        u = KAG::User::User.new(user)
        u[:matches] = 0 unless u[:matches]
        u[:matches] = u[:matches].to_i + 1
        u.save
      end

      def self.subtract_match(user)
        u = KAG::User::User.new(user)
        if u[:matches]
          u[:matches] = u[:matches].to_i + 1
        else
          u[:matches] = 0
        end
        u.save
      end

      def self.stats(user)
        u = KAG::User::User.new(user)
        "#{user.nick} has played in #{u.matches} matches."
      end

      protected

      def _load
        return {} unless self[:authname]

        unless File.exists?("data/#{self[:authname]}.json")
          File.open("data/#{self[:authname]}.json","w") {|f| f.write("{}") }
        end

        f = ::IO.read("data/#{self[:authname]}.json")
        if f and !f.empty?
          SymbolTable.new(JSON.parse(f))
        else
          SymbolTable.new
        end
      end
    end
  end
end